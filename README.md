# no-vibe

Learn how things work from Claude instead of having Claude generate everything for you.

## Who this is for

If you feel like AI is draining your skill, making you forget how to do things, or you just want to actually understand how things work — this plugin is for you.

## How it works

Turn on no-vibe mode and Claude becomes a tutor instead of a code generator. It shows you code in the chat, explains it, and reviews what you write — but it won't touch your project files. You do the typing.

A lesson usually goes like this: look at what you already have, sketch the API from the top down, optionally ground it in a real reference project, build it step by step (Claude shows, you type), get a review, and save a short recap you can come back to.

### Install

#### Claude Code

In Claude Code, add the marketplace and install the plugin:

```
/plugin marketplace add rizukirr/no-vibe
/plugin install no-vibe@no-vibe
```

Then restart Claude Code.

#### OpenCode

Add no-vibe to your `opencode.json` plugin list:

```json
{
  "plugin": ["no-vibe@git+https://github.com/rizukirr/no-vibe.git"]
}
```

Restart OpenCode, then run:

```text
/no-vibe on
```

You can then use the same command forms:

```text
/no-vibe build a linear layer like pytorch's
/no-vibe --ref pytorch --mode concept how does autograd work
/no-vibe off
```

See `.opencode/INSTALL.md` for troubleshooting and details.

### Usage

```
/no-vibe on                                    # persistent mode
/no-vibe off                                   # exit mode
/no-vibe build a linear layer like pytorch's   # one-shot lesson
/no-vibe --ref pytorch --mode concept how does autograd work
```

Flags: `--ref <name-or-url>` attaches a reference project (URLs shallow-clone into `.no-vibe/refs/`); `--mode {concept|skill|debug}` sets the teaching style.
