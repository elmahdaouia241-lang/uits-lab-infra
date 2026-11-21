.PHONY: lint check-secrets validate help

help:
	@echo "make lint           shellcheck sur tous les scripts"
	@echo "make check-secrets  recherche de jetons/mots de passe en clair"
	@echo "make validate       tests de bout en bout du lab (depuis un hote du lab)"

lint:
	find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck -S warning

check-secrets:
	@! grep -rnEi '(password|passwd|token|secret)[^=]*=["'"'"' ]*[A-Za-z0-9+/_-]{16,}' . --exclude-dir=.git --exclude=Makefile \
	  | grep -vE 'ZBX_DB_PASSWORD|GLPI_DB_PASSWORD|\$$\{|\$$\(|REMPLACER_PAR' \
	  && echo "Aucun secret detecte"

validate:
	./scripts/validate-lab.sh
