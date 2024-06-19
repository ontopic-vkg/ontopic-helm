#!/usr/bin/env bash

set -e

if [[ -n "$BASH_VERSION" ]]; then
  echo "Using Bash"
elif [[ -n "$ZSH_VERSION" ]]; then
  echo "Using Zsh"
else
  echo "Unknown shell, bash or zsh supported"
  exit 1
fi

if [[ "$PWD" =~ \  ]]
then
  echo "Warning: path '$PWD' has spaces"
fi


read_optional() {
  local prompt="$1"
  local default="$2"
  local var="$3"
  if [[ -n "$BASH_VERSION" ]]; then
   read -p "$prompt [$default]: " -r "${var?}"
   export "$var"="${!var:-$default}"
  elif [[ -n "$ZSH_VERSION" ]]; then
   read -r "reply?${prompt} [$default]: "
   export "$var=${reply:-$default}"
  fi
}

write_directories() {
  local folder="$1"

  if [[ ! -d "$folder" ]]; then
    mkdir -p "$folder";
  fi

}

if [[ -n "$BASH_VERSION" ]]; then
  read -p "Do you want to remove all users and create a new user account? (y/n):" answer
elif [[ -n "$ZSH_VERSION" ]]; then
  read "answer?Do you want to remove all users and create a new user account? (y/n):"
fi
case ${answer:0:1} in
    y|Y)
        echo "Creating a new user!"
        # Authentication
        read_optional "Insert username" "test" USERNAME
        read_optional "Insert email" "test@email.it" USER_EMAIL
        read_optional "Insert full name" "test" USER_FULLNAME
        read_optional "Insert group" "developers" USER_GROUP

        write_directories "./secrets"

        docker run -it -v "./secrets:/mnt" ghcr.io/ontopic-vkg/ontopic-helm/identity-service:helm htpasswd -c /mnt/password-file-db "$USERNAME"
        sed -i "2s/:/:$USER_EMAIL/2" "./secrets/password-file-db"
        sed -i "2s/:/:$USER_FULLNAME/3" "./secrets/password-file-db"
        sed -i "2s/:/:$USER_GROUP/4" "./secrets/password-file-db"

        ;;
    *)
        echo "Skipping user creation."
        ;;
esac

