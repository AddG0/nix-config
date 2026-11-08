# The git remote behind `nix flake metadata --json`, to fetch its locked rev from; empty when git cannot fetch the source.
if .locked.type == "github" then "https://github.com/\(.locked.owner)/\(.locked.repo).git"
elif .locked.type == "git" then .locked.url
else ""
end
