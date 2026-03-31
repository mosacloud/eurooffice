# ---------------------------------------------------------------------------
# Vagrant VM testing targets
# ---------------------------------------------------------------------------

.PHONY: vagrant-up vagrant-up-ubuntu vagrant-up-debian vagrant-up-rocky vagrant-destroy vagrant-ssh

vagrant-up: ## Bring up all Vagrant test VMs
	@cd vagrant && vagrant up

vagrant-up-ubuntu: ## Bring up Ubuntu 24.04 VM only
	@cd vagrant && vagrant up ubuntu2404

vagrant-up-debian: ## Bring up Debian 12 VM only
	@cd vagrant && vagrant up debian12

vagrant-up-rocky: ## Bring up Rocky Linux 9 VM only
	@cd vagrant && vagrant up rocky9

vagrant-destroy: ## Destroy all Vagrant VMs
	@cd vagrant && vagrant destroy -f

vagrant-ssh: ## SSH into a Vagrant VM (usage: make vagrant-ssh VM=ubuntu2404)
	@cd vagrant && vagrant ssh $(VM)
