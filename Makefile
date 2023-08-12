MOCKS_DIR = test/mocks
CONTRACTS_DIR = contracts

.PHONY: symlinks clean

all: symlinks

symlinks:
	@echo "Creating symlinks from $(MOCKS_DIR) to $(CONTRACTS_DIR)..."
	@for file in $(MOCKS_DIR)/*.sol; do \
		ln -sf ../$$file $(CONTRACTS_DIR)/; \
		echo "Symlink created for $$file"; \
	done

clean:
	@echo "Removing symlinks..."
	@for file in $(MOCKS_DIR)/*.sol; do \
		basefile=`basename $$file`; \
		rm -f $(CONTRACTS_DIR)/$$basefile; \
	done
