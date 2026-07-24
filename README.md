# Homebrew Tap

## Preamble

Before you can make use of these Homebrew Formula, you'll have to `brew trust autumnjolitz/tap` first.

## Crossfire Homebrew Tap

Crossfire is a free, open-source, cooperative multiplayer RPG and adventure game.

[Project](https://crossfire.real-time.com/) | [Source](https://sourceforge.net/projects/crossfire/) | [Wiki](https://wiki.cross-fire.org/)

![Screenshot of crossfire-client-gtk2](/docs/screenshot1.png?raw=true "session on metalforge.net")

### crossfire-client-gtk2

`brew install --HEAD autumnjolitz/tap/crossfire-client`

## xsoldier Homebrew Tap

[xsoldier](http://www.interq.or.jp/libra/oohara/xsoldier/index.html) is a shoot 'em up game with the \"not shooting\" bonus.

<img src="/docs/xsoldier.png?raw=true" width="600">

### xsoldier
`brew install autumnjolitz/tap/xsoldier`

## Python 2.4 Homebrew Tap

Python 2.4 is legacy and clearly unmaintained, however older Zope installations require it.

Python 2.4 comes with:

- pip 1.1 (aliased to `pip2.4`)
- setuptools 1.4.2 (aliased to `easy_install-2.4`)


### python2.4

`brew install autumnjolitz/tap/python@24`

## Python 2.7 Homebrew Tap

Python 2.7 is legacy and clearly unmaintained, however older Zope installations require it.

Python 2.7 comes with the last known Python 2.7-compatible releases for:

- pip 20.3.4 (aliased to `pip2.7`)
- setuptools 44.1.1 (aliased to `easy_install-2.7`)
- virtualenv 20.15.1(alised to `virtualenv-2.7`)


### python2.7

`brew install autumnjolitz/tap/python@27`


## Zope 2.11 Homebrew Tap

Zope 2.11 is legacy software. It's of relevance for preservation of 1990-2005 websites written in it.

This fork of Zope 2.11 is meant for circumstances where legacy Zope is required and you don't wish to expose even `localhost:PORT` to reduce one's vulnerability surface.

New Features:
- ZServer/HTTP (`medusa`) accepts `bind-to ADDRESS` where `ADDRESS` may be one of the following:
  * `ip:port`
  * Path for UNIX Domain Socket

Fixed Bugs:
- TAL engine throws TypeError on XML/HTML fragments

Known Bugs:
- Unix Domain Sockets don't remove stale socket files
  * TODO: upon binding a Unix Domain Socket, fork off/exec a small watcher script that waits for the read end of a pipe to close, then unlinks the stale file.
- CGI server is broken for serving file streams
  * GETs on an image for example returns:
```
<open file 'Zope.jpg', mode 'r' at 0x140020378>
```

### zope2.11

`brew install autumnjolitz/tap/zope@211`






