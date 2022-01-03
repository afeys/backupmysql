#!/bin/bash

##############################################################
# Script: backupmysql.sh                                          
# Author: Andy Feys (andy@feys.be)                           
# Date:   Sunday April 25th 2021                             
##############################################################

readonly SCRIPTNAME=`basename "$0"`
readonly VERSION='0.8'
readonly AUTHOR="Andy Feys"

##############################################################
# Initializing some variables                                
##############################################################

# initializing some color variables, useful for outputting text
# more info can be found at https://en.wikipedia.org/wiki/ANSI_escape_code
BLACK='\033[0;30m'
RED='\033[0;31m'
BRIGHTRED='\033[1;31m'
GREEN='\033[0;32m'
BRIGHTGREEN='\033[1;32m'
YELLOW='\033[0;33m'
BRIGHTYELLOW='\033[1;33m'
BLUE='\033[0;34m'
BRIGHTBLUE='\033[1;34m'
MAGENTA='\033[0;35m'
BRIGHTMAGENTA='\033[1;35m'
CYAN='\033[0;36m'
BRIGHTCYAN='\033[1;36m'
WHITE='\033[0;37m'
BRIGHTWHITE='\033[1;37m'
RESET='\033[0;0m'

# Some variables to store command line parameters
clp_show_help=false
clp_interactive_mode=false
clp_restore=""
clp_config_file_name=""
clp_write_config_file=""           # store the current config in a file with this name
clp_directory_to_store_backup=""
clp_comment=""

clp_tempdirectory=""
clp_backupmode=""               # can be FULL (default), "DATA", "STRUCTURE" or "GRANTS";
clp_mysqlhost=""
clp_mysqluser=""
clp_mysqlpassword=""
clp_mysqldatabase=""

##############################################################
# functions                                                  
##############################################################

function array_contains() {
  local n=$#
  local value=${!n}
  for ((i=1;i < $#;i++)) {
    if [ "${!i}" == "${value}" ]; then
      echo "y"
      return 0
    fi
  }	
  echo "n"
  return 1
}

function clean_comment() {
  a=${1//[^[:alpha:]]/_}
  a=${a//__/_}
  echo "${a,,}"
}

function trim_comment() {
  a=${1:0:50}
  echo "${a,,}"
}

function get_users_homedir() {
  echo $( getent passwd "$USER" | cut -d: -f6 )  # store the backupfile by default in the users' home directory
}

#unused
#function isvarset(){
#	 local v="$1"
#	 [[ ! ${!v} && ${!v-unset} ]] && echo "Variable not found." || echo "Variable found."
#}

function show_welcome() {
  echo -e "${GREEN}+-----------------------------------------------------------------------+${RESET}"
  echo -e "${GREEN}|${RESET} ${BRIGHTBLUE}$SCRIPTNAME${RESET} $VERSION                                                         ${GREEN}|${RESET}" 
  echo -e "${GREEN}|${RESET} by ${GREEN}$AUTHOR${RESET}                                                          ${GREEN}|${RESET}" 
  echo -e "${GREEN}+-----------------------------------------------------------------------+${RESET}"
}

function show_intro() {
  show_welcome
  echo -e "$SCRIPTNAME -h or $SCRIPTNAME --help to show all options"
  echo -e " "
}

function show_help() {
  show_welcome
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} ${BRIGHTGREEN}Usage${RESET}: $SCRIPTNAME [OPTION]...                                          ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} Backs up a mysql database to a tar.gz (or tar.gz.gpg) file.           ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} If no options are provided, then the program is started in            ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} interactive mode.                                                     ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} ${BRIGHTGREEN}Command line options${RESET}:                                                 ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -h, --help                        show help                           ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -myh, --mysqlhost <server or ip>  backup from this mysqlserver        ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -myu, --mysqluser <user>          connect with this mysql user        ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -myp, --mysqlpassword <password>  mysql user password                 ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -myd, --mysqldatabase <database>  backup this database                ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -m, --mode <backupmode>           FULL: everything                    ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                   DATA: only the data                 ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                   STRUCTURE: only the db structure    ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                   GRANTS: only the userrights         ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                         ${BRIGHTRED}Warning : FULL/GRANTS: Only for mysql > 5.7${RESET}   ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -t, --targetdir <targetdir>       store the backup in this folder     ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -tmp, --tempdir <tempdir>         directory to use for temp storage   ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -o, --comment <comment>           add a short comment to backup       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                   filename                            ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -i, --interactive                 start the program interactively     ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                   (all other parameters are ignored)  ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -c, --config <configfile>         load settings from configfile       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} -w, --writeconfig <configfile>    write settings to configfile        ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} ${BRIGHTGREEN}How to restore these files${RESET}:                                           ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} Start the mysql interactive shell and type                            ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET} SOURCE <filename.sql>;                                                ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}|${RESET}                                                                       ${GREEN}|${RESET}"
  echo -e "${GREEN}+-----------------------------------------------------------------------+${RESET}"
  echo -e " "
}


##############################################################
# get all command line parameters (if any)                   
##############################################################

clp_interactive_mode=true  # start in interactive mode by default

while [[ "$#" -gt 0 ]]
do
  case $1 in
    -h|--help)
      clp_interactive_mode=false
      clp_show_help=true
      ;; 
    -c|--config)
      clp_interactive_mode=false
      clp_config_file_name=$2
      ;;
    -myh|--mysqlhost)
      clp_interactive_mode=false
      clp_mysqlhost=$2
      ;;
    -myu|--mysqluser)
      clp_interactive_mode=false
      clp_mysqluser=$2
      ;;
    -myp|--mysqlpassword)
      clp_interactive_mode=false
      clp_mysqlpassword=$2
      ;;
    -myd|--mysqldatabase)
      clp_interactive_mode=false
      clp_mysqldatabase=$2
      ;;
    -m|--mode)
      clp_interactive_mode=false
      clp_backupmode=$2
      ;;
    -w|--writeconfig)
      clp_interactive_mode=false
      clp_write_config_file=$2
      ;;
    -t|--targetdir)
      clp_interactive_mode=false
      clp_directory_to_store_backup=$2
      ;;
    -tmp|--tempdir)
      clp_interactive_mode=false
      clp_tempdirectory=$2
      ;;
    -o|--comment)
      clp_interactive_mode=false
      clp_comment=$(clean_comment "$2")
      clp_comment=${clp_comment:0:50}
      ;;
    -i|--interactive)
      clp_interactive_mode=true
      ;;			
  esac	
  shift
done


##############################################################
# show welcome message                                       
##############################################################
if [ ${clp_show_help} == true ]
then
  show_help
  exit
else
  show_intro
fi


if [ ${clp_interactive_mode} == true ]
then

##############################################################
# INTERACTIVE MODE
##############################################################


  targetdirectory="/tmp"

  # enter the needed info about the database to backup
  ##############################################################

  echo -e "${GREEN}Database host:${RESET}"
  read databasehost
  echo -e "${GREEN}Database user:${RESET}"
  read databaseuser
  echo -e "${GREEN}Database password:${RESET}"
  read databasepassword
  echo -e "${GREEN}Database name:${RESET}"
  read databasename
  echo -e "${GREEN}What do you want to backup? (FULL/DATA/STRUCTURE/GRANTS):${RESET}"
  read backupmode

  # enter the targetdirectory where you want to store the backup
  ##############################################################

  echo -e "${GREEN}Targetdirectory:${RESET}"
  read targetdirectory
  
  # enter the tmpdirectory you want to use for temporary storage
  ##############################################################

  echo -e "${GREEN}Tempdirectory:${RESET}"
  read tempdirectory
  

  # enter some comment or info about this backup               
  ##############################################################

  echo -e "${GREEN}Please enter some comment about this backup (50char max), this will be appended to the filename:${RESET}"
  read backupcomment

  cleanedcomment=$(clean_comment "$backupcomment")
  cleanedcomment=${cleanedcomment:0:50}

  echo -e "${RED}$cleanedcomment${RESET}"

else # else of  "if [ ${clp_interactive_mode} == true }" statement

##############################################################
# NON-INTERACTIVE MODE
##############################################################
  if [ "${clp_config_file_name}" != "" ];
  then
  # load variables from config file
    while IFS='= ' read -r key value; do
      case $key in 
        "databasehost")
          databasehost=${value}
          ;;
        "databaseuser")
          databaseuser=${value}
          ;;
        "databasepassword")
          databasepassword=${value}
          ;;
        "databasename")
          databasename=${value}
          ;;
        "backupmode")
          backupmode=${value}
          ;;
        "targetdirectory")
          targetdirectory=${value}
          ;;
        "tempdirectory")
          tempdirectory=${value}
          ;;
        "comment")
          cleanedcomment=${value}
          ;;
      esac        
    done < $clp_config_file_name
  fi

  # load variables from command line parameters
  if [ "${clp_mysqlhost}" != "" ];
  then
    databasehost=${clp_mysqlhost}
  fi
  if [ "${clp_mysqluser}" != "" ];
  then
    databaseuser=${clp_mysqluser}
  fi
  if [ "${clp_mysqlpassword}" != "" ];
  then
    databasepassword=${clp_mysqlpassword}
  fi
  if [ "${clp_mysqldatabase}" != "" ];
  then
    databasename=${clp_mysqldatabase}
  fi
  if [ "${clp_backupmode}" != "" ];
  then
    backupmode=${clp_backupmode}
  fi
  if [ "${clp_directory_to_store_backup}" != "" ];
  then
    targetdirectory=${clp_directory_to_store_backup}
  fi
  if [ "${clp_tempdirectory}" != "" ];
  then
    tempdirectory=${clp_tempdirectory}
  fi
  if [ "${clp_comment}" != "" ];
  then
   cleanedcomment=${clp_comment}
  fi

  # write variables to config file if needed
  if [ "${clp_write_config_file}" != "" ];
  then
    # write config to config file
    echo "databasehost = ${databasehost}" > ${clp_write_config_file}
    echo "databaseuser = ${databaseuser}" >> ${clp_write_config_file}
    echo "databasepassword = ${databasepassword}" >> ${clp_write_config_file}
    echo "databasename = ${databasename}" >> ${clp_write_config_file}
    echo "backupmode = ${backupmode}" >> ${clp_write_config_file}
    echo "targetdirectory = ${targetdirectory}" >> ${clp_write_config_file}
    echo "tempdirectory = ${tempdirectory}" >> ${clp_write_config_file}
    echo "comment = ${cleanedcomment}" >> ${clp_write_config_file}
  fi

fi # end of "if [ ${clp_interactive_mode} == true }" statement


echo -e "DEBUG INFO...."
echo -e "databasehost = ${databasehost}"
echo -e "databaseuser = ${databaseuser}"
echo -e "databasepassword = ${databasepassword}"
echo -e "databasename = ${databasename}"
echo -e "backupmode = ${backupmode}"
echo -e "targetdirectory = ${targetdirectory}"
echo -e "tempdirectory = ${tempdirectory}"
echo -e "comment = $cleanedcomment"


##############################################################
# do the backup                                              
##############################################################
# do a backup
# first construct the filename where the backup will be stored
targetfile="${databasename}_$(date +%Y%m%d)_$cleanedcomment"
targetfiledata="${targetfile}_data.sql"
targetfilestructure="${targetfile}_structure.sql"
targetfilegrants="${targetfile}_grants.sql"
cd $targetdirectory
echo -e "Starting backup of ${GREEN}$databasename${RESET}. "
if [ "${backupmode}" == "FULL" ];
then
  mysqldump --column-statistics=0 --host=${databasehost} --user=${databaseuser} --password=${databasepassword} ${databasename} > $targetfiledata
  mysqlpump --host=${databasehost} --user=${databaseuser} --password=${databasepassword} --databases ${databasename} --users > $targetfilegrants
fi
if [ "${backupmode}" == "DATA" ];
then
  mysqldump --column-statistics=0 --no-create-db --no-create-info --host=${databasehost} --user=${databaseuser} --password=${databasepassword} ${databasename} > $targetfiledata
fi
if [ "${backupmode}" == "STRUCTURE" ];
then
  mysqldump --column-statistics=0 --no-data --host=${databasehost} --user=${databaseuser} --password=${databasepassword} ${databasename} > $targetfilestructure
fi
if [ "${backupmode}" == "GRANTS" ] || [ "${backupmode}" == "FULL" ];
then
  #mysqlpump --host=${databasehost} --user=${databaseuser} --password=${databasepassword} --databases ${databasename} --users > $targetfilegrants
  mysql -u${databaseuser} -p${databasepassword} -h${databasehost} -e"select concat('show grants for ','\'',user,'\'@\'',host,'\'') from mysql.user" > user_list_with_header.txt
  sed '1d' user_list_with_header.txt > ./user.txt
  while read user; do  mysql -u${databaseuser} -p${databasepassword} -h${databasehost} -e"$user" > user_grant.txt; sed '1d' user_grant.txt >> user_privileges.txt; echo "flush privileges" >> user_privileges.txt; done < user.txt
  awk '{print $0";"}'  user_privileges.txt > $targetfilegrants
  rm user.txt user_list_with_header.txt user_grant.txt user_privileges.txt
fi
echo -e "$SCRIPTNAME finished."
