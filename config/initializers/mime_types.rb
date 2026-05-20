# Register text/markdown so Rails can route /d/:token.md correctly and
# render markdown responses with the right Content-Type.
Mime::Type.register "text/markdown", :md
