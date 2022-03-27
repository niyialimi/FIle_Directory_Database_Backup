#!/bin/bash

# A control Script to backup files, directories, and database schemas.
# Written by Niyi Alimi
# USAGE: It can be used as Cron/Scheduler or Human Interraction
#CRON:
  # example cron for daily File/Directory backup @ 11:00pm
  # min  hr mday month wday                           command
  # 00   23  *    *     *    /home/oracle/scripts/practicedir_niyi_dec21/backup_control.sh C F emailaddress@gmail.com /home/oracle/scripts/practicedir_niyi_dec21 /backup/AWSDEC21/NIYIALIMI/PRACTICEDIR_BACKUP

#-----VARIABLE DECLARATION----#
#--$1 is the first line argument = The Flag to choose if it's a Cron job or Human-- 
#--$2 is the second line argument = Backup Type--
#--$3 is the third line argument = Email address to send status notice--
#--$4 is the fourth line argument = FIle or Diectory source--
#--$5 is the fifth line argument = Backup location for file or Directory--
#--$6 is the sixth line argument = The Database name--
#--$7 is the seventh line argument = Flag to indicate if an SQL statement would be run for the backup--
#--$8 is the eight line argument = The person running the script
#--$9 is the night line argument = The Database backup Location

COMFLAG=$1
BACKUP_TYPE=$2
EMAIL=$3
SOURCE_LOCATION=/home/oracle/scripts/practicedir_niyi_dec21
BACKUP_LOCATION=/backup/AWSDEC21/NIYIALIMI/PRACTICEDIR_BACKUP
BACKUP_DAYS=5

#--To Create a timestamp at runtime for the backup file--
#--The back tick executes the timestamp command and assigns the value to TS.--
TS=`date +%d%m%y%H%M%S`


#--------FUNCTIONS--------#
CREATE_BK_LOCATION() {
   #---Declearing the Diectory Backup location--
 	BACKUPLOC=${BACKUP_LOCATION}/${TS}

   #--Condition to check if the backup location already exists--
   if [ -d ${BACKUPLOC} ]
   then
      echo "---------------------------------------------"
      echo "Backup directory ${BACKUPLOC} already exists."
      echo "---------------------------------------------"
   else
      #--Create the Backup location with sub directories--

		mkdir -p ${BACKUPLOC}
      #---Check exit status of the mkdir command--
      #---If the exit status is 0, then it is successful, else, it failed.--
         if [[ $? == 0 ]]
         then
            echo "--------------------------------------------------"
            echo "The ${BACKUPLOC} directory creation was successful"
            echo "--------------------------------------------------"
         else
            echo "------------------------------------------"
            echo "The ${BACKUPLOC} directory creation failed"
            echo "------------------------------------------"
         fi
   fi
}

#--Copy file into backup_location---#
COPY_FILE_DIRECTORY() {
   #--The R is to copy recursively--
   cp -R ${SOURCE_LOCATION} ${BACKUPLOC}
   #--Condition to check the exit status of the copy command---
      if [[ $? == 0 ]]
      then
         echo "----------------------------------------------------"
         echo "The ${SOURCE_LOCATION} directory copy was successful"
         echo "----------------------------------------------------"
         
         #---Send status Email--
         echo "File or directory ${SOURCE_LOCATION} backup was successful."|mailx -s "The backup of file or directory ${SOURCE_LOCATION} was successful" ${EMAIL}
      else
         echo "--------------------------------------------"
         echo "The ${SOURCE_LOCATION} directory copy failed"
         echo "--------------------------------------------"
               
         #---Send status Email--
         echo "File or directory ${SOURCE_LOCATION} backup failed, notifying on-call personnel"|mailx -s "The backup of file or directory ${SOURCE_LOCATION} failed, your ATTENTION is needed" ${EMAIL}
      fi

}

#------Database Environment Variable and Physical Location-----#
DB_SETUP() {
   . /home/oracle/scripts/oracle_env_${DB}.sh
                  
   #---Create Physical directory  
   #---Declearing the Database Backup location--
   DB_BACKUP=${DB_BACKUP_LOC}/${RUNNER^^}/${TS}
   
   mkdir -p ${DB_BACKUP}
}

#------Parameter Files and Run Database Backup----#
PAR_FILE() {
   echo "userid=' / as sysdba' "> ${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
   echo "schemas= ${SCHEMA}">> ${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
   echo "dumpfile= ${SCHEMA}_${RUNNER}.dmp" >> ${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
   echo "logfile= ${SCHEMA}_${RUNNER}.log" >> ${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
   echo "directory= DATA_PUMP_${RUNNER}" >> ${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
               
   #---Run the expdp script for Database backup--
   echo "Backing up the schema ${SCHEMA} from database ${DB}"
   expdp parfile=${NIYIALIMI_HOME}/DB_PAR_FILES/backup_${SCHEMA}_${DB}.par
}

#------Database Email Notification------#
DB_STATUS_MESSAGE() {
   if ( grep "successfully completed" ${DB_BACKUP}/${SCHEMA}_${RUNNER}.log )
   then
      echo "--------------------------------------"
      echo "Database backup completed sucessfully"
      echo "--------------------------------------" 
                  
      #---Send status Email--
      echo "Database Schema ${SCHEMA} backup from ${DB} was successful." | mailx -s "The backup of the Database Schema ${SCHEMA} from ${DB}  was successful was successful" ${EMAIL} < ${DB_BACKUP}/${SCHEMA}_${RUNNER}.log
   else
      echo "-------------------------"
      echo "Database backup failed"             
      echo "-------------------------"
                  
      echo "Database Schema ${SCHEMA} backup from ${DB} failed, notifying on-call personnel" | mailx -s "The backup of the Database Schema ${SCHEMA} from ${DB} failed, your ATTENTION is needed" ${EMAIL} < ${DB_BACKUP}/${SCHEMA}_${RUNNER}.log
   fi
}


#------Compressthe backup file without the parent folder-----#
FILE_COMPRESS() {
   tar -czvf ${BACKUPLOC}.tar.gz -C ${BACKUPLOC} . && rm -R ${BACKUPLOC}
      if [[ $? == 0 ]]
      then
         echo "--------------------------------------------------"
         echo "The ${BACKUPLOC} direcotry was compressed successful"
         echo "--------------------------------------------------"
      else
         echo "------------------------------------------"
         echo "The ${BACKUPLOC} directory compression failed"
         echo "------------------------------------------"
      fi

   #------List and Remove Files and Directories older than 3 days----#
   find ${BACKUP_LOCATION} -type f -mtime ${BACKUP_DAYS} -exec ls -ltrd {} \;
   find ${BACKUP_LOCATION} -type f -mtime ${BACKUP_DAYS} -exec rm -rf {} \;
   find ${BACKUP_LOCATION} -type d -mtime ${BACKUP_DAYS} -exec ls -ltrd {} \;
   find ${BACKUP_LOCATION} -type d -mtime ${BACKUP_DAYS} -exec rm -rf {} \;
}

#----Compress the database backup file without the parent folder-----#
DB_COMPRESS() {
   tar -czvf ${DB_BACKUP}.tar.gz -C ${DB_BACKUP} . && rm -R ${DB_BACKUP}
   if [[ $? == 0 ]]
   then
      echo "--------------------------------------------------"
      echo "The ${DB_BACKUP} direcotry was compressed successful"
      echo "--------------------------------------------------"
   else
      echo "------------------------------------------"
      echo "The ${DB_BACKUP} directory compression failed"
      echo "------------------------------------------"
   fi

   #------List and Remove old FIles and Directories----#
   find ${DB_BACKUP_LOC}/${RUNNER^^} -type f -mtime ${BACKUP_DAYS} -exec ls -ltrd {} \;
   find ${DB_BACKUP_LOC}/${RUNNER^^} -type f -mtime ${BACKUP_DAYS} -exec rm -rf {} \;
   find ${DB_BACKUP_LOC}/${RUNNER^^} -type d -mtime ${BACKUP_DAYS} -exec ls -ltrd {} \;
   find ${DB_BACKUP_LOC}/${RUNNER^^} -type d -mtime ${BACKUP_DAYS} -exec rm -rf {} \;
}

#----MAIN BODY----#

#---Specifying How the script would be run---
#---Cron/Scheduled Job---
if [[ ${COMFLAG} == 'C' ]]
then
   echo "This is a Cron Job!! Checking the type of backup being performed"

   #----Specifying the backup type---
   #----File/Directory Backup---
   if [[ ${BACKUP_TYPE} == 'F' ]]
   then
      echo "Performing File or Directory Backup"

      #---Check if user have the right commandline argument---
      if [[ $# != 5 ]]
      then
         echo "You need to enter below command line arguments.
			-Comflag: Schedule in Crontab or Run Manually
			-Backup Type: F-File or Directory backup
         -Email
			-Source File or Directory
			-Backup Location"
         exit
      else
         #----CREATE BACKUP LOCATION----#
			CREATE_BK_LOCATION

         #--Copy file into backup_location--
         COPY_FILE_DIRECTORY

         #----Compressthe backup file----
         FILE_COMPRESS
      fi
  
   #---Database Backup----
   elif [[ ${BACKUP_TYPE} == 'D' ]]
   then
      echo "Performing a database backup"

      #---Check if user have the right commandline argument---
		echo "Counting command line arguements to ensure you have the right arguements for your backup"

      if [[ $# != 8 ]]
      then
      	echo "You need to enter below command line arguments.
			-Comflag: Schedule in Crontab or Run Manually
			-Backup Type: D- Database backup  
			-Email
			-Database: Database to backup
			-SqlPass: Option to pass in SQL statement- Y or N
			-Schema List: SQL, File, Or Schema list
			-Runner: Runner of the scripts name
			-Backup Location"
			exit
		else
         echo "#############PERFORM DATABASE LOGICAL EXPORT USING DATAPUMP#######"
         DB=$4
			SQLPASS=$5
			SCHEMALIST=$6
			RUNNER=$7
			DB_BACKUP_LOC=$8

         #----Specifying how the schema is passed----
         #-----Schema as SQL Statement---

         case ${SQLPASS} in 
            'Y')
               echo "We are backing up the database by passing in sqlstatement"
               SQLSTATEMENT=${SCHEMALIST}
               echo "You are running ${SQLSTATEMENT} SQL statement in the ${DB} database"

               #---#Set Environmnet Vairable for the database and Create Physical directory---
               DB_SETUP

               #---Login to database--- 
               sqlplus -s username/password << EOF
               set heading off pagesize 0 term off echo off feedback off
               --Getting the results on the SQL into a log file
               spool '${NIYIALIMI_HOME}/db_schema_list.log'	
               ${SQLSTATEMENT}
               --Pointing the Logical location to the physical location
               create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
               spool off
EOF

               #---Notification message about the schema list---
               echo "Backing up the attached list of schemas from the ${DB} database" |  mailx -s "Schema backup list from database ${DB}" ${EMAIL} < ${NIYIALIMI_HOME}/db_schema_list.log

               #---Looping through the schema list--- 
               while read SCHEMA
               do 
                  PAR_FILE

                  DB_STATUS_MESSAGE

               done< ${NIYIALIMI_HOME}/db_schema_list.log

               #----Compress the database backup-----
               DB_COMPRESS
               exit
               ;;
            'N')
               echo "We are backing up the database by passing in a file list of schemas"
               FILE_LIST=${SCHEMALIST}
               
               echo "You are looping through the schemas in ${FILE_LIST}"
               
               DB_SETUP
               
               #---Login to the Database-
               sqlplus -s username/password << EOF

               --Pointing the Logical location to the physical location
               create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
                     
EOF
               #---Looping through the schema list---
               while read SCHEMA
               do
                  PAR_FILE

                  DB_STATUS_MESSAGE

               done<${FILE_LIST}

               #----Compress the database backup-----
               DB_COMPRESS
               exit
               ;;
            *)
               echo "Passing a list of schemas and 'for' looping through them to perform the backup"

               DB_SETUP
               
               #---Login to the Database-
               sqlplus -s username/password << EOF

               --Pointing the Logical location to the physical location
               create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
                     
EOF
            
               echo "You are 'For' looping the ${SCHEMALIST} list and creating backups"
               for SCHEMA in ${SCHEMALIST}
               do
                  PAR_FILE

                  DB_STATUS_MESSAGE
               done

               #----Compress the database backup-----
               DB_COMPRESS
               ;;
         esac

      fi
   fi

else
   #---Running the script as a human---
	echo "This is a human running this dope script!"
	read -p "Type of backup: F-FIle or Directory, D-Database: " BACKUP_TYPE
	if [[ $BACKUP_TYPE == 'F' ]]
	then
      echo "Grabbing extra arguements for your file or directory backup....."
		read -p "Please Enter Source File or Directory: " SOURCE_LOCATION
		read -p "Please Enter Destination Directory: " BACKUP_LOCATION
		read -p "Please Enter Your Email: " EMAIL

      #----CREATE BACKUP LOCATION----#
		CREATE_BK_LOCATION

      #--Copy file into backup_location--
      COPY_FILE_DIRECTORY

      #----Compressthe backup file----
      FILE_COMPRESS

   elif [[ $BACKUP_TYPE == 'D' ]]
   then
      echo "You are Backing Up a Database Schema"
      read -p "Please Enter Your Email: " EMAIL
      read -p "Database to backup: " DB
      read -p "Enter the runner: " RUNNER
      read -p "Enter the Backup Location: " DB_BACKUP_LOC

      #-----DATABASE------
      #---Check if the databse process is running---
		if [[ `ps -ef|grep pmon|grep ${DB}` ]]
		then
         echo "---------------------------------"
			echo "The database is presently running"
			echo "---------------------------------"
		
			DB_SETUP
			
			#---Check to confirm the Database is what was specified---
         if [[ $ORACLE_SID == "${DB}" ]]
			then
				echo "----------------------"
				echo "The Database is ${DB}"
				echo "----------------------" 

            #---Login to the Database-
				sqlplus -s username/password<<EOF

				--Pointing the Logical location to the physical location
				create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
EOF
            read -p "Are you backing up less than ten database schemas? Please enter Y for yes, and N for No : " ANS
            
            if [[ ${ANS} == 'Y' ]]
            then
               echo "Collecting an array of schemas!"
               read -p "Please enter your list of schemas in an array (delimited by space) like schema1 schema2 schema3: " SCHEMALIST
               
               for SCHEMA in ${SCHEMALIST}
               do
                  echo "I am backing up schema: ${SCHEMA}"

                  #---Creating the expdp file with the parameters---
                  echo "Creating the datapump parameter file for backup......"
                  PAR_FILE
                        
                  DB_STATUS_MESSAGE
               done

               #----Compress the database backup-----
               DB_COMPRESS
				else
               echo "There are two options to backing up more than ten schemas"
               echo "1) You can pass an SQL statement into a database to generate the list of users"
               echo "2) You can pass in a file of schemas and loop through the schem as in the file to backup"

               options=' 1 2 '
               PS3='Select an option: '
               select option in $options
               do
                  if [[ ${option} == 1 ]]
                  then
                     echo "You are passing an SQL statement that generates the database users to backup"
                     read -p "Enter SQL statement: " SQLSTATEMENT
                     echo "You entered ${SQLSTATEMENT}"

                     #---Login to the Database-
                     sqlplus -s username/password<<EOF

                     set heading off pagesize 0 term off echo off feedback off
            
                     --Pointing the Logical location to the physical location
                     create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
            
                     --Getting the results on the SQL into a log file
                     spool '${NIYIALIMI_HOME}/db_schema_list.log'
            
                     ${SQLSTATEMENT}

                     spool off
EOF
                     #---Notification message about the schema list---
                     echo "Backing up the attached list of schemas from the ${DB} database" |  mailx -s "Schema backup list from database ${DB}" ${EMAIL} < ${NIYIALIMI_HOME}/db_schema_list.log
                     
                     #---Looping through the schema list---
                     while read SCHEMA
                     do
                        #---Creating the expdp file with the parameters---
                        echo "Creating the datapump parameter file for backup......"
                        
                        PAR_FILE
            
                        DB_STATUS_MESSAGE
                     done < ${NIYIALIMI_HOME}/db_schema_list.log

                     #----Compress the database backup-----
                     DB_COMPRESS
                     exit
						elif [[ $option == 2 ]]
                  then
                     echo "You are passing in an absolute path of a file that has a schema list"   
                     read -p "Please Enter Full Path Of Your File Of Schemas: " SCHEMA_FILE_PATH

                     echo "You are looping through the schemas in ${FILE_LIST}"

                     #---Login to the Database-
                     sqlplus -s username/password<<EOF
            
                     --Pointing the Logical location to the physical location
                     create or replace directory DATA_PUMP_${RUNNER^^} as '${DB_BACKUP}';
EOF
                     #---Looping through the schema list---
                     while read SCHEMA
                     do
                        #---Creating the expdp file with the parameters---
                        echo "Creating the datapump parameter file for backup......"
                        PAR_FILE
                     
                        DB_STATUS_MESSAGE
                     done < ${SCHEMA_FILE_PATH}

                     #----Compress the database backup-----
                     DB_COMPRESS
                     exit
                    
                  else 
                   echo "Do Nothing"
                  fi
               done
            fi
			else
            echo "------------------------------------"
            echo "Please ensure the database is ${DB}"
            echo "------------------------------------"
         fi

      else 
         echo "--------------------------------"
         echo "The database is not presently running"
         echo "--------------------------------"
      fi
   fi
fi