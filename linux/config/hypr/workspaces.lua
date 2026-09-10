hl.workspace_rule({ workspace = "1", persistent = true, default = true })

for i = 2, 10 do
  hl.workspace_rule({ workspace = tostring(i), persistent = true })
end