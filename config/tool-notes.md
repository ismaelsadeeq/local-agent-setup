# Tool notes

## You can run code: the `shell` tool
The `shell` tool runs a command in the project folder and gives you its real output. You are not
limited to writing text: run things and look at the results.
- Run a script: `python3 script.py <args>`
- Run tests: `python3 test_x.py`, or for a tests/ folder `python3 -m unittest discover -s tests -t .`
- Check a file compiles: `python3 -m py_compile file.py`
- Anything longer than one statement: write a .py file and run it. Don't put loops or `if` blocks in `python3 -c "...; for ..."` (that is a SyntaxError). Use `python3`, not `python`.
- See what's there: `ls`, `ls -R dir | head -50`
Work in this cycle until it's done:
1. Read the files the task mentions, including any tests (they tell you what "correct" means).
2. Make one change.
3. Run the code or tests with the `shell` tool and read the output.
4. If anything fails, fix it and go back to step 3.
Never finish with "this should work" or "you can run X to check": run X yourself and report what it printed.

## When unsure how a command works
1. `tldr <command>` (e.g. `tldr git-log`, `tldr find`): short offline examples. Use it before a command you're unsure of, and after any usage error.
2. `<command> --help 2>&1 | grep -i -A3 -- '<flag>'`: details for one option. Never print a whole manual; it fills your context.
3. Still stuck: ask the research subagent to fetch the official docs page (needs user approval; not available in unattended runs).
After a usage error, change the command. Never re-run the same failing command.

## Answers must come from output
Every name, date and number in an answer must appear in output you received in this session. If the output didn't contain it, re-run a better command or say you couldn't find it. Never fill a gap with a guess.

## git (newest commit first unless --reverse; put options BEFORE `-- <path>`)
- Last change to a file: `git log -1 --format='%an %ad' --date=short -- path`
- First change: `git log --reverse --format='%an %ad' --date=short -- path | head -1`
- Commits per author for a file: `git shortlog -sn HEAD -- path`
- Who changed a file, all commits: `git log --format='%h %an %ad %s' --date=short -- path`
- What changed in a commit: `git show --stat <hash>`

## Files and folders
- Biggest entries in a folder: `du -sk path/* | sort -rn | head`
- Count lines/files: `wc -l file`, `find path -type f | wc -l`
- Rename in place: `mv "dir/old name" "dir/new name"`. Keep the directory in the target path. Check `[ -e "$target" ]` before moving, so you never overwrite.
- Never use the write/edit tools to rename or move files: they replace contents.
- After a bulk change, list the result (`ls dir | head`, `ls dir | wc -l`) and compare with what you expected.

## Look before you parse
Before writing code that parses a web page, API response or file, look at the real thing first: `curl -s URL | head -60`, `curl -sI URL` (headers), `head -20 file`. Write the parser for what you actually saw, never for what you assume the format is. macOS grep has no -P; use python3 for parsing.

## Big text files and logs
- Don't `cat` big files (output is cut off). Use `wc -l`, `head -20`, `tail -20`, `grep -c`, `grep -n`.
- Errors per minute: `grep ERROR file | cut -c12-16 | sort | uniq -c | sort -rn | head`
- Most common messages: `grep ERROR file | cut -d' ' -f4- | sort | uniq -c | sort -rn | head`

## Python scripts
- After writing a script, run it on the sample input and look at the output before saying it works.
- Read CSV with `csv.DictReader`; quoted fields can contain commas, so never split CSV lines on ','.
- JSON output: `json.dumps(obj)`; check it parses: `python3 -c 'import json,sys; json.load(sys.stdin)' < out.json`
