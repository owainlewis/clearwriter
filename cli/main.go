// cw — a thin CLI over the atrium HTTP API, for humans and AI agents.
//
// Single static binary, stdlib only — drop it on PATH and an agent can read,
// search, and write docs with no runtime to install.
//
// Config (env wins over ~/.config/cw/config, which holds KEY=VALUE lines):
//
//	CW_API_URL   base URL of the app   (default http://localhost:3000)
//	CW_TOKEN     bearer token          (create one in Settings -> API tokens)
//
// Docs are addressed by their public id (the Base58 token; `cw ls` shows it).
// Body content is markdown; the title is derived from the first H1 server-side,
// so you never set it directly — just write markdown.
//
// Examples:
//
//	cw ls --tag onboarding
//	cw search "billing webhook"
//	cw cat 7Qk... > doc.md
//	cw new < notes.md                  # create from stdin, prints the new id
//	echo "# Updated" | cw write 7Qk...  # replace body from stdin
//	cw publish <collection-id> < post.md
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

const usage = `cw — atrium CLI

Usage: cw <command> [args] [--json]

Documents
  ls [--tag T] [--since 7d]   list your docs (newest first)
  search <query>              find docs by title/body substring
  cat <id>                    print a doc's markdown to stdout
  new [file]                  create a doc from file or stdin; prints id
  write <id> [file]           replace a doc's body from file or stdin
  rm <id>                     delete a doc

Collections
  cols                        list collections
  col <id>                    show a collection and its docs
  publish <col-id> [file]     create a doc from file/stdin and attach it

Other
  whoami                      verify connection and token
  help                        show this message

Flags
  --json    emit raw JSON instead of a table (ls/search/cols/col/whoami)
  --tag T   filter (ls)
  --since   relative window like 7d (ls)
`

// fail prints "cw: <msg>" to stderr and exits non-zero. Used for every error
// path so the contract is uniform: message on stderr, exit code 1.
func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "cw: "+format+"\n", a...)
	os.Exit(1)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		fmt.Print(usage)
		return
	}
	cmd, rest := args[0], args[1:]
	pos, flags := parseArgs(rest)

	cfg := loadConfig()

	switch cmd {
	case "help", "-h", "--help":
		fmt.Print(usage)
		return
	case "ls":
		newClient(cfg).list(flags)
	case "search":
		newClient(cfg).search(pos, flags)
	case "cat":
		newClient(cfg).cat(pos)
	case "new":
		newClient(cfg).create(pos)
	case "write":
		newClient(cfg).write(pos)
	case "rm":
		newClient(cfg).remove(pos)
	case "cols":
		newClient(cfg).collections(flags)
	case "col":
		newClient(cfg).collection(pos, flags)
	case "publish":
		newClient(cfg).publish(pos)
	case "whoami":
		newClient(cfg).whoami(cfg, flags)
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n\n%s", cmd, usage)
		os.Exit(1)
	}
}

// parseArgs splits raw args into positionals and flags. Flags may appear in any
// position (mirroring the Ruby OptionParser#order! behavior). Recognized:
// --json (bool), --tag <v>, --since <v>. "--tag=x" form is also accepted.
func parseArgs(args []string) (pos []string, flags map[string]string) {
	flags = map[string]string{}
	for i := 0; i < len(args); i++ {
		a := args[i]
		switch {
		case a == "--json":
			flags["json"] = "true"
		case a == "--tag" || a == "--since":
			if i+1 < len(args) {
				flags[strings.TrimPrefix(a, "--")] = args[i+1]
				i++
			}
		case strings.HasPrefix(a, "--tag="):
			flags["tag"] = strings.TrimPrefix(a, "--tag=")
		case strings.HasPrefix(a, "--since="):
			flags["since"] = strings.TrimPrefix(a, "--since=")
		default:
			pos = append(pos, a)
		}
	}
	return pos, flags
}

type config struct {
	apiURL string
	token  string
}

// loadConfig resolves config with env taking precedence over the config file.
func loadConfig() config {
	file := readConfigFile()
	pick := func(key, def string) string {
		if v := os.Getenv(key); v != "" {
			return v
		}
		if v, ok := file[key]; ok {
			return v
		}
		return def
	}
	return config{
		apiURL: strings.TrimRight(pick("CW_API_URL", "http://localhost:3000"), "/"),
		token:  pick("CW_TOKEN", ""),
	}
}

func readConfigFile() map[string]string {
	out := map[string]string{}
	home, err := os.UserHomeDir()
	if err != nil {
		return out
	}
	data, err := os.ReadFile(filepath.Join(home, ".config", "cw", "config"))
	if err != nil {
		return out
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if ok {
			out[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	return out
}

type client struct {
	base  string
	token string
}

func newClient(cfg config) *client {
	if cfg.token == "" {
		fail("No token. Set CW_TOKEN or add CW_TOKEN= to ~/.config/cw/config.")
	}
	return &client{base: cfg.apiURL, token: cfg.token}
}

// do performs an HTTP request and returns the raw response body. A non-2xx
// status raises a fail() with the server's error message. body/contentType are
// used for content writes; jsonBody for JSON requests; query for the URL query.
func (c *client) do(method, path string, query url.Values, jsonBody any, body []byte, contentType string) []byte {
	u := c.base + path
	if len(query) > 0 {
		u += "?" + query.Encode()
	}

	var reader io.Reader
	ct := ""
	switch {
	case jsonBody != nil:
		b, err := json.Marshal(jsonBody)
		if err != nil {
			fail("encoding request: %v", err)
		}
		reader = bytes.NewReader(b)
		ct = "application/json"
	case body != nil:
		reader = bytes.NewReader(body)
		ct = contentType
	}

	req, err := http.NewRequest(method, u, reader)
	if err != nil {
		fail("%v", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Accept", "application/json")
	if ct != "" {
		req.Header.Set("Content-Type", ct)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		fail("%v", err)
	}
	defer res.Body.Close()
	respBody, _ := io.ReadAll(res.Body)

	if res.StatusCode < 200 || res.StatusCode >= 300 {
		fail("%d %s", res.StatusCode, errorMessage(respBody, res.Status))
	}
	return respBody
}

// errorMessage extracts a human message from a JSON error body, falling back to
// the raw body or the HTTP status line.
func errorMessage(body []byte, status string) string {
	var e struct {
		Message string `json:"message"`
		Error   string `json:"error"`
	}
	if json.Unmarshal(body, &e) == nil {
		if e.Message != "" {
			return e.Message
		}
		if e.Error != "" {
			return e.Error
		}
	}
	if s := strings.TrimSpace(string(body)); s != "" {
		return s
	}
	return status
}

type doc struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	UpdatedAt string `json:"updated_at"`
}

type collection struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	DocumentCount int    `json:"document_count"`
	Documents     []doc  `json:"documents"`
}

// printDocs writes tab-separated rows: id, date (YYYY-MM-DD), title.
func printDocs(docs []doc) {
	for _, d := range docs {
		date := d.UpdatedAt
		if len(date) >= 10 {
			date = date[:10]
		}
		fmt.Printf("%s\t%s\t%s\n", d.ID, date, d.Title)
	}
}

func printJSON(raw []byte) {
	var v any
	if json.Unmarshal(raw, &v) != nil {
		fmt.Println(string(raw))
		return
	}
	out, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(out))
}

// readInput returns the body from an explicit file arg, or stdin if piped.
// ok is false when neither is available (callers treat that as a usage error).
func readInput(pos []string) (data []byte, ok bool) {
	if len(pos) > 0 {
		b, err := os.ReadFile(pos[0])
		if err != nil {
			fail("%v", err)
		}
		return b, true
	}
	if stat, _ := os.Stdin.Stat(); (stat.Mode() & os.ModeCharDevice) == 0 {
		b, _ := io.ReadAll(os.Stdin)
		return b, true
	}
	return nil, false
}

func abortUsage(u string) {
	fmt.Fprintf(os.Stderr, "usage: cw %s\n", u)
	os.Exit(1)
}

func (c *client) list(flags map[string]string) {
	q := url.Values{}
	if v := flags["tag"]; v != "" {
		q.Set("tag", v)
	}
	if v := flags["since"]; v != "" {
		q.Set("since", v)
	}
	raw := c.do("GET", "/api/v1/documents", q, nil, nil, "")
	c.emitDocs(raw, flags)
}

func (c *client) search(pos []string, flags map[string]string) {
	query := strings.Join(pos, " ")
	if query == "" {
		abortUsage("search <query>")
	}
	raw := c.do("GET", "/api/v1/documents", url.Values{"q": {query}}, nil, nil, "")
	c.emitDocs(raw, flags)
}

func (c *client) emitDocs(raw []byte, flags map[string]string) {
	if flags["json"] == "true" {
		printJSON(raw)
		return
	}
	var docs []doc
	if err := json.Unmarshal(raw, &docs); err != nil {
		fail("decoding response: %v", err)
	}
	printDocs(docs)
}

func (c *client) cat(pos []string) {
	if len(pos) == 0 {
		abortUsage("cat <id>")
	}
	raw := c.do("GET", "/api/v1/documents/"+pos[0]+"/content", nil, nil, nil, "")
	os.Stdout.Write(raw)
}

func (c *client) create(pos []string) {
	body, ok := readInput(pos)
	if !ok {
		abortUsage("new [file]   (or pipe markdown via stdin)")
	}
	raw := c.do("POST", "/api/v1/documents", nil, map[string]string{"body": string(body)}, nil, "")
	var d doc
	json.Unmarshal(raw, &d)
	fmt.Println(d.ID)
}

func (c *client) write(pos []string) {
	if len(pos) == 0 {
		abortUsage("write <id> [file]")
	}
	id := pos[0]
	body, ok := readInput(pos[1:])
	if !ok {
		abortUsage("write <id> [file]   (or pipe markdown via stdin)")
	}
	c.do("PUT", "/api/v1/documents/"+id+"/content", nil, nil, body, "text/markdown; charset=utf-8")
	fmt.Fprintln(os.Stderr, "ok")
}

func (c *client) remove(pos []string) {
	if len(pos) == 0 {
		abortUsage("rm <id>")
	}
	c.do("DELETE", "/api/v1/documents/"+pos[0], nil, nil, nil, "")
	fmt.Fprintln(os.Stderr, "deleted")
}

func (c *client) collections(flags map[string]string) {
	raw := c.do("GET", "/api/v1/collections", nil, nil, nil, "")
	if flags["json"] == "true" {
		printJSON(raw)
		return
	}
	var cols []collection
	if err := json.Unmarshal(raw, &cols); err != nil {
		fail("decoding response: %v", err)
	}
	for _, col := range cols {
		fmt.Printf("%s\t%d\t%s\n", col.ID, col.DocumentCount, col.Name)
	}
}

func (c *client) collection(pos []string, flags map[string]string) {
	if len(pos) == 0 {
		abortUsage("col <id>")
	}
	raw := c.do("GET", "/api/v1/collections/"+pos[0], nil, nil, nil, "")
	if flags["json"] == "true" {
		printJSON(raw)
		return
	}
	var col collection
	if err := json.Unmarshal(raw, &col); err != nil {
		fail("decoding response: %v", err)
	}
	fmt.Printf("# %s (%d)\n", col.Name, col.DocumentCount)
	printDocs(col.Documents)
}

func (c *client) publish(pos []string) {
	if len(pos) == 0 {
		abortUsage("publish <col-id> [file]")
	}
	col := pos[0]
	body, ok := readInput(pos[1:])
	if !ok {
		abortUsage("publish <col-id> [file]   (or pipe markdown via stdin)")
	}
	raw := c.do("POST", "/api/v1/collections/"+col+"/documents", nil, map[string]string{"body": string(body)}, nil, "")
	var d doc
	json.Unmarshal(raw, &d)
	fmt.Println(d.ID)
}

func (c *client) whoami(cfg config, flags map[string]string) {
	raw := c.do("GET", "/api/v1/documents", nil, nil, nil, "")
	var docs []doc
	json.Unmarshal(raw, &docs)
	if flags["json"] == "true" {
		out, _ := json.MarshalIndent(map[string]any{
			"api_url":        cfg.apiURL,
			"ok":             true,
			"document_count": len(docs),
		}, "", "  ")
		fmt.Println(string(out))
		return
	}
	fmt.Printf("ok — %s (%d docs)\n", cfg.apiURL, len(docs))
}
