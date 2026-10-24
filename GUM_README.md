# Gum

[![Gum Image](https://stuff.charm.sh/gum/gum.png)](https://stuff.charm.sh/gum/nutritional-information.png)

[![Latest Release](https://img.shields.io/github/release/charmbracelet/gum.svg)](https://github.com/charmbracelet/gum/releases)
[![Go Docs](https://godoc.org/github.com/golang/gddo?status.svg)](https://pkg.go.dev/github.com/charmbracelet/gum?tab=doc)
[![Build Status](https://github.com/charmbracelet/gum/workflows/build/badge.svg)](https://github.com/charmbracelet/gum/actions)

A tool for glamorous shell scripts. Leverage the power of
[Bubbles](https://github.com/charmbracelet/bubbles) and [Lip
Gloss](https://github.com/charmbracelet/lipgloss) in your scripts and aliases
without writing any Go code!

![Shell running the ./demo.sh script](https://vhs.charm.sh/vhs-1qY57RrQlXCuydsEgDp68G.gif)

The above example is running from a single shell script ([source](./examples/demo.sh)).

## Tutorial

Gum provides highly configurable, ready-to-use utilities to help you write
useful shell scripts and dotfile aliases with just a few lines of code.
Let's build a simple script to help you write
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary)
for your dotfiles.

Ask for the commit type with gum choose:

```bash
gum choose "fix" "feat" "docs" "style" "refactor" "test" "chore" "revert"
```

> [!NOTE]
> This command itself will print to stdout which is not all that useful. To make use of the command later on you can save the stdout to a `$VARIABLE` or `file.txt`.

Prompt for the scope of these changes:

```bash
gum input --placeholder "scope"
```

Prompt for the summary and description of changes:

```bash
gum input --value "$TYPE$SCOPE: " --placeholder "Summary of this change"
gum write --placeholder "Details of this change"
```

Confirm before committing:

```bash
gum confirm "Commit changes?" && git commit -m "$SUMMARY" -m "$DESCRIPTION"
```

Check out the [complete example](https://github.com/charmbracelet/gum/blob/main/examples/commit.sh) for combining these commands in a single script.

![Running the ./examples/commit.sh script to commit to git](https://vhs.charm.sh/vhs-7rRq3LsEuJVwhwr0xf6Er7.gif)

## Installation

Use a package manager:

```bash
# macOS or Linux
brew install gum

# Arch Linux (btw)
pacman -S gum

# Fedora or EPEL 10
dnf install gum

# Nix
nix-env -iA nixpkgs.gum

# Flox
flox install gum

# Windows (via WinGet or Scoop)
winget install charmbracelet.gum
scoop install charm-gum
```

<details>
<summary>Debian/Ubuntu</summary>

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

</details>

<details>
<summary>Fedora/RHEL/OpenSuse</summary>

```bash
echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
sudo rpm --import https://repo.charm.sh/yum/gpg.key

# yum
sudo yum install gum

# zypper
sudo zypper refresh
sudo zypper install gum
```

</details>

<details>
<summary>FreeBSD</summary>

```bash
# packages
sudo pkg install gum

# ports
cd /usr/ports/devel/gum && sudo make install clean
```

</details>

Or download it:

- [Packages][releases] are available in Debian, RPM, and Alpine formats
- [Binaries][releases] are available for Linux, macOS, Windows, FreeBSD, OpenBSD, and NetBSD

Or just install it with `go`:

```bash
go install charm.land/gum/v2@latest
```

[releases]: https://github.com/charmbracelet/gum/releases

## Commands

- [`choose`](#choose): Choose an option from a list of choices
- [`confirm`](#confirm): Ask a user to confirm an action
- [`file`](#file): Pick a file from a folder
- [`filter`](#filter): Filter items from a list
- [`format`](#format): Format a string using a template
- [`input`](#input): Prompt for some input
- [`join`](#join): Join text vertically or horizontally
- [`pager`](#pager): Scroll through a file
- [`spin`](#spin): Display spinner while running a command
- [`style`](#style): Apply coloring, borders, spacing to text
- [`table`](#table): Render a table of data
- [`write`](#write): Prompt for long-form text
- [`log`](#log): Log messages to output

## Customization

You can customize `gum` options and styles with `--flags` and `$ENVIRONMENT_VARIABLES`.
See `gum <command> --help` for a full view of each command's customization and configuration options.

Customize with `--flags`:

```bash

gum input --cursor.foreground "#FF0" \
          --prompt.foreground "#0FF" \
          --placeholder "What's up?" \
          --prompt "* " \
          --width 80 \
          --value "Not much, hby?"
```

Customize with `ENVIRONMENT_VARIABLES`:

```bash
export GUM_INPUT_CURSOR_FOREGROUND="#FF0"
export GUM_INPUT_PROMPT_FOREGROUND="#0FF"
export GUM_INPUT_PLACEHOLDER="What's up?"
export GUM_INPUT_PROMPT="* "
export GUM_INPUT_WIDTH=80

# --flags can override values set with environment
gum input
```

![Gum input displaying most customization options](https://vhs.charm.sh/vhs-5zb9DlQYA70aL9ZpYLTwKv.gif)

## Input

Prompt for input with a simple command.

```bash
gum input > answer.txt
gum input --password > password.txt
```

![Shell running gum input typing Not much, you?](https://vhs.charm.sh/vhs-1nScrStFI3BMlCp5yrLtyg.gif)

## Write

Prompt for some multi-line text (`ctrl+d` to complete text entry).

```bash
gum write > story.txt
```

![Shell running gum write typing a story](https://vhs.charm.sh/vhs-7abdKKrUEukgx9aJj8O5GX.gif)

## Filter

Filter a list of values with fuzzy matching:

```bash
echo Strawberry >> flavors.txt
echo Banana >> flavors.txt
echo Cherry >> flavors.txt
gum filter < flavors.txt > selection.txt
```

![Shell running gum filter on different bubble gum flavors](https://vhs.charm.sh/vhs-61euOQtKPtQVD7nDpHQhzr.gif)

Select multiple options with the `--limit` flag or `--no-limit` flag. Use `tab` or `ctrl+space` to select, `enter` to confirm.

```bash
cat flavors.txt | gum filter --limit 2
cat flavors.txt | gum filter --no-limit
```

## Choose

Choose an option from a list of choices.

```bash
echo "Pick a card, any card..."
CARD=$(gum choose --height 15 {{A,K,Q,J},{10..2}}" "{♠,♥,♣,♦})
echo "Was your card the $CARD?"
```

You can also select multiple items with the `--limit` or `--no-limit` flag, which determines
the maximum of items that can be chosen.

```bash
cat songs.txt | gum choose --limit 5
cat foods.txt | gum choose --no-limit --header "Grocery Shopping"
```

![Shell running gum choose with numbers and gum flavors](https://vhs.charm.sh/vhs-3zV1LvofA6Cbn5vBu1NHHl.gif)

## Confirm

Confirm whether to perform an action. Exits with code `0` (affirmative) or `1`
(negative) depending on selection.

```bash
gum confirm && rm file.txt || echo "File not removed"
```

![Shell running gum confirm](https://vhs.charm.sh/vhs-3xRFvbeQ4lqGerbHY7y3q2.gif)

## File

Prompt the user to select a file from the file tree.

```bash
$EDITOR $(gum file $HOME)
```

![Shell running gum file](https://vhs.charm.sh/vhs-2RMRqmnOPneneIgVJJ3mI1.gif)

## Pager

Scroll through a long document with line numbers and a fully customizable viewport.

```bash
gum pager < README.md
```

![Shell running gum pager](https://vhs.charm.sh/vhs-3iMDpgOLmbYr0jrYEGbk7p.gif)

## Spin

Display a spinner while running a script or command. The spinner will
automatically stop after the given command exits.

To view or pipe the command's output, use the `--show-output` flag.

```bash
gum spin --spinner dot --title "Buying Bubble Gum..." -- sleep 5
```

![Shell running gum spin while sleeping for 5 seconds](https://vhs.charm.sh/vhs-3YFswCmoY4o3Q7MyzWl6sS.gif)

Available spinner types include: `line`, `dot`, `minidot`, `jump`, `pulse`, `points`, `globe`, `moon`, `monkey`, `meter`, `hamburger`.

## Table

Select a row from some tabular data.

```bash
gum table < flavors.csv | cut -d ',' -f 1
```

<!-- <img src="https://stuff.charm.sh/gum/table.gif" width="600" alt="Shell running gum table" /> -->

## Style

Pretty print any string with any layout with one command.

```bash
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	'Bubble Gum (1¢)' 'So sweet and so fresh!'
```

![Bubble Gum, So sweet and so fresh!](https://github.com/charmbracelet/gum/assets/42545625/67468acf-b3e0-4e78-bd89-360739eb44fa)

## Join

Combine text vertically or horizontally. Use this command with `gum style` to
build layouts and pretty output.

Tip: Always wrap the output of `gum style` in quotes to preserve newlines
(`\n`) when using it as an argument in the `join` command.

```bash
I=$(gum style --padding "1 5" --border double --border-foreground 212 "I")
LOVE=$(gum style --padding "1 4" --border double --border-foreground 57 "LOVE")
BUBBLE=$(gum style --padding "1 8" --border double --border-foreground 255 "Bubble")
GUM=$(gum style --padding "1 5" --border double --border-foreground 240 "Gum")

I_LOVE=$(gum join "$I" "$LOVE")
BUBBLE_GUM=$(gum join "$BUBBLE" "$GUM")
gum join --align center --vertical "$I_LOVE" "$BUBBLE_GUM"
```

![I LOVE Bubble Gum written out in four boxes with double borders around them.](https://github.com/charmbracelet/gum/assets/42545625/68f7a25d-b495-48dd-982a-cee0c8ea5786)

## Format

`format` processes and formats bodies of text. `gum format` can parse markdown,
template strings, and named emojis.

```bash
# Format some markdown
gum format -- "# Gum Formats" "- Markdown" "- Code" "- Template" "- Emoji"
echo "# Gum Formats\n- Markdown\n- Code\n- Template\n- Emoji" | gum format

# Syntax highlight some code
cat main.go | gum format -t code

# Render text any way you want with templates
echo '{{ Bold "Tasty" }} {{ Italic "Bubble" }} {{ Color "99" "0" " Gum " }}' \
    | gum format -t template

# Display your favorite emojis!
echo 'I :heart: Bubble Gum :candy:' | gum format -t emoji
```

For more information on template helpers, see the [Termenv
docs](https://github.com/muesli/termenv#template-helpers). For a full list of
named emojis see the [GitHub API](https://api.github.com/emojis).

![Running gum format for different types of formats](https://github.com/charmbracelet/gum/assets/42545625/5cfbb0c8-0022-460d-841b-fec37527ca66)

## Log

`log` logs messages to the terminal using different levels and styling using
the [`charmbracelet/log`](https://github.com/charmbracelet/log) library.

```bash
# Log some debug information.
gum log --structured --level debug "Creating file..." name file.txt
# DEBUG Creating file... name=file.txt

# Log some error.
gum log --structured --level error "Unable to create file." name file.txt
# ERROR Unable to create file. name=temp.txt

# Include a timestamp.
gum log --time rfc822 --level error "Unable to create file."
```

See the Go [`time` package](https://pkg.go.dev/time#pkg-constants) for acceptable `--time` formats.

See [`charmbracelet/log`](https://github.com/charmbracelet/log) for more usage.

![Running gum log with debug and error levels](https://vhs.charm.sh/vhs-6jupuFM0s2fXiUrBE0I1vU.gif)

## Examples

How to use `gum` in your daily workflows:

See the [examples](./examples/) directory for more real world use cases.
