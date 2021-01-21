#!/usr/bin/env bash

## Function for setting up github repository for config versioning.
## This function can be invoked INTERACTIVE OR UNATTENDED.
## 
##    versioning_setup()
##
versioning_setup() {

  local user 
  local email 
  local repository 
  local token 
  local logPrefix="$(timestamp) [openHABian]"
  local introText="This is to create your own repository with you're config files for versioning and offsite storage. \\n\\nBefore setting up here you need to create an Github account, repository and access token.\\n\\nNOTE: This is not a full backup solution and will stop and restart openhab\\n\\n  Do you want to continue?"
  local installFound="Vesioning previously installed.\\n\\nUninstall will not delete online repository or local config files\\n\\nWould you like to Uninstall."
  local questionText="Please enter"

  # shellcheck disable=SC2154
  user="$github_user"
  # shellcheck disable=SC2154
  email="$github_email"
  # shellcheck disable=SC2154
  repository="$github_repository"
  # shellcheck disable=SC2154
  token="$github_token"

  if [[ -n $UNATTENDED ]] 
  then
    if [[ -z $github_token ]] # Check of credentials loaded from openhabaian.conf 
    then
      echo "$logPrefix Github Versioning setup... CANCELED (No token found loaded)"
      return 0
    fi
  fi

  echo -n "$logPrefix Check if vesioning already exists..."
  if [ -d /.git ] # Make sure someone hasn't already init git on root folder
  then
    echo -n " Previous installation found"
    if [[ -n $INTERACTIVE ]];  then
      if (whiptail --title "Versioning github already installed" --yes-button "Uninstall" --no-button "Cancel" --yesno "$installFound" 14 80)
      then
        echo "Uninstall"  
        versioning_uninstall
      else 
        echo " CANCELED installation"
        return 0
      fi
    fi
  fi

  echo -n "$logPrefix Beginning the github repository setup... "
  if [[ -n $INTERACTIVE ]]
  then 
    if (whiptail --title "Versioning Github" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 14 80)
    then
      echo "OK"
    else 
      echo "CANCELED"
      return 0 
  fi
 
  echo "$logPrefix Stopping openhab"; systemctl stop openhab.service
  echo -n "$logPrefix Gathering Credentials for Github..."

    if [ -z "$user" ]
    then
      if ! user="$(whiptail --title "Versioning Github" --inputbox "\\nGithub Username?" 8 39 --title "$questionText Username" 3>&1 1>&2 2>&3)"; then
        echo "CANCELED (username)"; return 0
      fi
    fi

    if [ -z "$email" ]
    then
      if ! email="$(whiptail --title "Versioning Github" --inputbox "\\nGithub Email?" 8 39 --title "$questionText Email" 3>&1 1>&2 2>&3)"; then
        echo "CANCELED (email)"; return 0
      fi
    fi

    if [ -z "$repository" ] 
    then
      if ! repository="$(whiptail --title "Versioning Github" --inputbox "\\nGithub Repository?" 8 39 --title "$questionText Repository" 3>&1 1>&2 2>&3)"; then
        echo "CANCELED (repository"; return 0
      fi
    fi

    if [ -z "$token" ]
    then
      if ! token="$(whiptail --title "Versioning Github" --inputbox "\\nGithub token?" 8 39 --title "$questionText Token" 3>&1 1>&2 2>&3)"; then
        echo "CANCELED (token)"; return 0
      fi
    fi
    echo " OK"
  fi
   
  echo -n "$logPrefix Ensuring network connectivity... "
  if ! running_in_docker && tryUntil "ping -c1 8.8.8.8 &> /dev/null || curl --silent --head https://github.com/ |& grep -qs 'HTTP/1.1 200 OK'" 5 1
  then
    echo "FAILED (Can't reach github)"
    return 0
  else
    echo " OK"
  fi
  
  repourl="https://$user:$token@github.com/$user/$repository.git"
  echo -n "$logPrefix Check if $repository Exists and credentials valid..."
  if git ls-remote "$repourl" | grep "HEAD" > /dev/null 
  then
    echo " OK"
  else
    echo " FAIL"
      if [[ -n $INTERACTIVE ]] 
      then 
        whiptail --title "Operation Fail" --msgbox "Fail invalid credentials\\nYou entered\\n\\nUser         $user\\nEmail         $email\\nrepository  $repository\\nToken        $token" 15 80
      fi
    return 0
  fi

  echo -n "$logPrefix Check if $repository is set to Private..."
  if curl -s --head --request GET https://github.com/"$user"/"$repository" | grep "HTTP/2 404" > /dev/null
  then
    echo " OK"
  else
    echo " FAIL (Public repository)"
    if [[ -n $INTERACTIVE ]]
    then
      whiptail --title "Openhabian Versioning" --msgbox "Please Set Repository [$repository] to Private on Github and try again" 8 78
      return 0
    fi
  fi
 
  apiurl="https://api.github.com/repos/$user/$repository/contents/openhabian_config_versioning"
  echo -n "$logPrefix Check online Repository [$repository] contains previous install..."

  if curl -s -H "Accept: application/vnd.github.v3+json" -i -u "$user":"$token" "$apiurl" | grep "HTTP/1.1 200 OK" > /dev/null
  then
    echo -n " YES" # using update_git_repo() caused git to delete everything
    if ! cond_redirect git -C "/" init; then echo "FAILED (init)"; return 1; fi
    if ! cond_redirect git -C "/" remote add origin "$repourl"; then echo "FAILED (add remote url)"; return 1; fi
    if ! cond_redirect git -C "/" fetch; then echo "FAILED (fetch origin)"; return 1; fi
    if ! cond_redirect git -C "/" reset origin/master; then echo "FAILED (reset to origin)"; return 1; fi
    if ! cond_redirect git -C "/" checkout . ; then echo "FAILED (checkout)"; return 1; fi
    if cond_redirect git -C "/" pull origin master; then echo " SUCCESS"; 
      else 
        echo "FAILED (pull origin master probably conflicting files)"
        echo -n "$logPrefix Removing Failed INSTALL"
        if cond_redirect rm -rf /.git; then echo -n ".OK"; else echo ".FAILED (remove .git)"; fi
        if [[ -n $INTERACTIVE ]]
          then
            whiptail --title "Failed Install" --msgbox "You're untracked local system has the same file as remote repository\\n\\nAborted to keep your local files\\nReparing is beyond the scope of this tool\\n" 15 78
            return 0
          fi
      return 1
    fi
  else
    echo "NO - Create new"
    cond_redirect git init / 
    git -C "/" remote add origin "$repourl"
    echo "$logPrefix This file is intentionally left empty" > /openhabian_config_versioning
    cp "${BASEDIR:-/opt/openhabian}/includes/cfg-gitignore.txt" /.gitignore
  fi

  if ! git -C "/" config user.name
  then 
    git -C "/" config user.user "$user"
  else 
    existing_userename=$(git -c "/" config user.name)
    echo "$logPrefix git name already set [$existing_userename]... SKIPPED"
  fi

  if ! git -C "/" config user.email
  then 
    git -C "/" config user.email "$email"
  else 
    existing_email=$(git -c "/" config user.email)
    echo "$logPrefix git email already set [$existing_email]... SKIPPED"
  fi

  git -C "/" config versioning.repository "$repository"
  git -C "/" config versioning.token "$token"
  cond_redirect git -C "/" push --set-upstream origin master
  git -C "/" config alias.cmp '!f() { git add -A && git commit -m "$@" && git push; }; f'

  if [[ -n $INTERACTIVE ]]
  then
    systemctl start openhab.service
    whiptail --title "Operation Successful!" --msgbox "Setup was successful.\\n\\nGithub repository with the name [$repository] is now up and running.\\nIt is ready for you to commit.\\n\\nYou can also enable auto commit daily" 15 80
  fi

}


## Function for uninstall up github repository for config versioning.
## This function can be invoked only INTERACTIVE.
##
##    versioning_uninstall()
##
versioning_uninstall() {

  if [ ! -f /.gitignore ] && [ ! -d /.git ]
  then
    echo "$(timestamp) [openHABian] No Versioning installation found "
    (whiptail --title "Versioning Github" --yes-button "Continue" --no-button "Cancel" --yesno "No Versioning Found" 14 80) ; return 0
  fi
  currentrepo=$(cond_redirect sed -n -e "s/^.*\\(branch \\)/\\1/p" /.git/FETCH_HEAD)
  if (whiptail --title "Versioning Github" --yes-button "Continue" --no-button "Cancel" --yesno "Found Existing repository\\n\\n$currentrepo\\n\\nUninstall Versioning are you sure you want to continue" 14 80)
  then
    echo "OK"
  else
    return 0
  fi

  echo -n "$(timestamp) [openHABian] Uninstalling Git Versioning..."
  if cond_redirect rm -rf /.git; then echo -n ".OK"; else echo ".FAILED (remove .git)"; return 1; fi
  if cond_redirect rm /.gitignore; then echo -n ".OK"; else echo ".FAILED (remove .gitignore)"; return 1; fi
  if cond_redirect rm /openhabian_config_versioning; then echo -n ".OK"; else echo ".FAILED (remove install check)"; return 1; fi
  echo ".Successfull"

  if [[ -n $INTERACTIVE ]]
  then
    whiptail --title "Operation Successfull" --msgbox "Local Versioning Removed" 5 80
  fi
}

## Enable timer to run commit.
## This function INTERACTIVE
## 
##    versioning_enable_auto_commit()
##
versioning_enable_auto_commit() {

  # Can run ./functions/config-versioning.bash commit 
  # if script has exicute permission for runnin in openhab rule

  true

}

## Disable timer to run commit.
## This function INTERACTIVE 
## 
##    versioning_disable_auto_commit()
##
versioning_disable_auto_commit() {

  true

}

## Function to commiting changes and PUSH to github repository for config versioning.
## This function INTERACTIVE 
## 
##    versioning_commit()
##
versioning_commit() {

  local commitMessage example exitcode=0

  if [ -d "/.git" ]
  then 
    echo "[openHABian] Start repository commit... "
    example="$(date) Manual Commit"
    if [[ -n $INTERACTIVE ]];  then  commitMessage="$(whiptail --title "Versioning github commit message" --inputbox "\\nCommit Message" 8 80 "$example" 3>&1 1>&2 2>&3)"
      exitcode=$?
    fi
    if [ $exitcode != 0 ]
    then
      return 0
    else  
      if [ -z "$commitMessage" ]; then  commitMessage="$(date) Auto Commit"; fi
      commit=$(git -C "/" cmp "$commitMessage")
      if [[ -n $INTERACTIVE ]];  then  whiptail --title "Versioning github" --scrolltext --msgbox "$commit" 25 80;  fi
    fi
  else
    echo "[openHABian] No repository Found to commit... "
    return 0
  fi

}

## Function is to update/change the github token used in config versioning.
## This functions only in INTERACTIVE
## 
##    versioning_commit()
##
versioning_tokenupdate() {

  local newtoken repository user newrepourl

  newtoken="$(whiptail --title "Versioning Github" --inputbox "\\nGithub Token?" 8 39 --title "Enter new Token" 3>&1 1>&2 2>&3)"
  repository=$(git -C "/" config versioning.repository)
  user=$(git -C "/" config user.user)
  newrepourl="https://$user:$newtoken@github.com/$user/$repository.git"
  echo "$newrepourl"
  echo -n "$(timestamp) [openHABian] Check if new token is valid..."
  if git ls-remote "$newrepourl" | grep "HEAD" > /dev/null 
  then
    git -C "/" remote set-url origin "$newrepourl"
    git -C "/" config versioning.token "$newtoken"
    echo " OK"
  else
    echo " FAIL"
    whiptail --title "Operation Fail" --msgbox "$newtoken\\nInvalid Token try again" 15 80
  fi

}


if [ "$1" == "commit" ]
then
  versioning_commit
fi
