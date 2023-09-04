# exit on error
set -o errexit

# setup
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy

# build
MIX_ENV=prod mix release --overwrite

# cleanup
mix phx.digest.clean --all