#!/usr/bin/env bash

BUILDPACK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Output utilities
puts_step() {
  echo "-----> $@"
}

puts_warn() {
  echo " !     $@"
}

puts_error() {
  echo " !     $@" >&2
  exit 1
}

# YAML parsing (simple)
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Add heroku add-on
add_addon() {
  local addon_name=$1
  local addon_plan=$2

  puts_step "Provisioning $addon_name ($addon_plan)"
  
  # In a real buildpack this would use the Heroku API
  # This is just a placeholder for demonstration
  echo "Would provision $addon_name with plan $addon_plan"
}

# Install Python package
install_package() {
  local package=$1
  
  puts_step "Installing $package"
  pip install $package
}