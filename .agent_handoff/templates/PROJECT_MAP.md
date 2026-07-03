# Project map

Optional but recommended for larger repos: copy this file to the repo root as
PROJECT_MAP.md and keep it current. Claude reads the map instead of exploring
the tree, which is much cheaper. One line per item; if it grows past ~60 lines, prune.

## Entry points
- <file> - <what it starts>

## Data flow
<source> -> <transform> -> <output>

## Key modules
- <dir or file> - <one-line responsibility>

## Verification
- <command that proves the project works>

## Do not touch
- <secrets, generated files, legacy areas>
