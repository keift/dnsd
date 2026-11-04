#!/usr/bin/env bash

yes | ssh-keygen -Y sign -f ~/.ssh/id_ed25519 -n file ./src/bin/dnsd.sh
yes | ssh-keygen -Y sign -f ~/.ssh/id_ed25519 -n file ./src/bin/dnsd_update.sh

echo "keift $(cat ~/.ssh/id_ed25519.pub)" > ./src/sign/ssh
