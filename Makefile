PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d

all:
	@echo "Run 'make install' to install sranime-cli."

install:
	install -Dm755 sranime-cli $(DESTDIR)$(BINDIR)/sranime-cli
	install -Dm644 sranime-cli.1 $(DESTDIR)$(MANDIR)/sranime-cli.1
	@if [ -f _sranime-cli-bash ]; then \
		install -Dm644 _sranime-cli-bash $(DESTDIR)$(BASHCOMPDIR)/sranime-cli; \
	fi
	@if [ -f _sranime-cli-zsh ]; then \
		install -Dm644 _sranime-cli-zsh $(DESTDIR)$(ZSHCOMPDIR)/_sranime-cli; \
	fi
	@if [ -f completions/sranime-cli.fish ]; then \
		install -Dm644 completions/sranime-cli.fish $(DESTDIR)$(FISHCOMPDIR)/sranime-cli.fish; \
	fi

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/sranime-cli
	rm -f $(DESTDIR)$(MANDIR)/sranime-cli.1
	rm -f $(DESTDIR)$(BASHCOMPDIR)/sranime-cli
	rm -f $(DESTDIR)$(ZSHCOMPDIR)/_sranime-cli
	rm -f $(DESTDIR)$(FISHCOMPDIR)/sranime-cli.fish

.PHONY: all install uninstall