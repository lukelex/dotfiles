;; extends

[
  (method)
  (singleton_method)
  (class)
  (module)
  (singleton_class)
  (block)
  (do_block)
] @ruby.outer

[
  (method
    body: (body_statement) @ruby.inner)
  (singleton_method
    body: (body_statement) @ruby.inner)
  (class
    body: (body_statement) @ruby.inner)
  (module
    body: (body_statement) @ruby.inner)
  (singleton_class
    body: (body_statement) @ruby.inner)
  (block
    body: (block_body) @ruby.inner)
  (do_block
    body: (body_statement) @ruby.inner)
]
