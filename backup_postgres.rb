#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'shellwords'
require 'pry'
require 'uri'
require 'yaml' 

action = ARGV[0]

remote_name = "dokku"
@dokku_user = "dokku"
@ubuntu_user = "dev"
@password = ""
@backups_path_remote = "/home/#{@ubuntu_user}/db_dumps"
@last_backup = "ls -v #{@backups_path_remote}"


if remote_name.nil?
  puts "USAGE: backup_postgres.rb [remote_name]"
  exit 1
end

url = `git remote get-url --push #{remote_name}`
 if $?.exitstatus > 0
  puts ""
  puts "Available remotes:"
  system("git remote -v")
  exit 1
 end

parsed_url = url.match(/.*@(.*):.*/)
remote_app_name = url.match(/.*:(.*)/)


@hostname = "#{parsed_url[1]}"


@dbhostname_cmd = "config:get #{remote_app_name[1]} DATABASE_HOSTNAME"
@dbname_cmd = "config:get #{remote_app_name[1]} DATABASE_NAME"
@dbpass_cmd = "config:get #{remote_app_name[1]} DATABASE_PASSWORD"
@dbusername_cmd = "config:get #{remote_app_name[1]} DATABASE_USERNAME"
@file_name = "db_backup.#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.sqlc"
@dburl_cmd = "config:get #{remote_app_name[1]} DATABASE_URL"


begin
  ssh = Net::SSH.start(@hostname, @dokku_user)
  url = (ssh.exec!(@dburl_cmd))
  ssh.close
end

if !url.nil? || !url.empty?


  url = URI.parse(url.strip)
    @database_hostname = url.host
    @database_name = url.path[1..-1]
    @database_password = url.password.gsub(/\n/,"").shellescape
    @database_username = url.user
else

begin
    ssh = Net::SSH.start(@hostname, @dokku_user)
    @database_hostname = (ssh.exec!(@dbhostname_cmd)).gsub(/\n/,"").shellescape
    @database_name = (ssh.exec!(@database_namee_cmd)).gsub(/\n/,"").shellescape    
    @database_password = (ssh.exec!(@dbpass_cmd)).gsub(/\n/,"").shellescape
    @database_username = (ssh.exec!(@dbusername_cmd)).gsub(/\n/,"").shellescape
    ssh.close
  rescue
    puts "Unable to connect to #{@hostname} using #{@username}/#{password}"
end
end


def backup
    puts 'backup process'
    @mkdir_cmd = "mkdir -p #{@backups_path_remote}"
    @backupdb_cmd = "PGPASSWORD=#{@database_password} pg_dump -U #{@database_username} -h #{@database_hostname} #{@database_name} -Fc --file=#{@backups_path_remote}/#{@file_name}"

  begin
    ssh = Net::SSH.start(@hostname, @ubuntu_user)
      backups_path = ssh.exec!(@mkdir_cmd)
      backup = ssh.exec!(@backupdb_cmd)
      puts @file_name
      puts backup
      ssh.close
      puts 'backup process finished'
  end
end 

def download
   puts 'downloading process'
  begin
      ssh = Net::SSH.start(@hostname, @ubuntu_user)
      backups_path = ssh.exec!(@last_backup)
      ssh.close
      puts backups_path
      @file_name_last = backups_path.split[-1]
      system("scp #{@ubuntu_user}@#{@hostname}:#{@backups_path_remote}/#{@file_name_last} /tmp")
     # puts @file_name_last
      puts 'downloading process finished' 
  rescue
    puts "error"
  end
end 

def restore_remote
     puts 'restoring remote database process'
      @pgpass_cmd = "touch ~/.pgpass && chmod 0600 ~/.pgpass"
      @credentials_cmd = "echo '*:*:*:#{@database_username}:#{@database_password}' > ~/.pgpass"
      @db_restore_cmd = "PGPASSFILE=~/.pgpass pg_restore --no-owner -h #{@database_hostname} -p 5432 -d #{@database_name} #{@file_name_last}"
      @rmpgpass_cmd = "rm ~/.pgpass"
  begin
    ssh = Net::SSH.start(@hostname, @ubuntu_user)
      pg_pass = ssh.exec!(@pgpass_cmd)
      db_credentials = ssh.exec!(@credentials_cmd)
      backups_path = ssh.exec!(@last_backup_cmd)
      @file_name_last = backups_path.split[-1]
      restore_db = ssh.exec!(@bd_restore_cmd)
      rmpgpass = ssh.exec!(@rmpgpass_cmd)
      ssh.close
        puts 'restoring process finished'
  end
end

def restore_localy
  puts 'restoring localy database process'
    dbconfig = YAML.load_file('config/database.yml')

    database_hostname=dbconfig['development']['host']
    database_name=dbconfig['development']['database']
    database_username=dbconfig['development']['username']
    database_password=(dbconfig['development']['password']).gsub(/\n/,"").shellescape
    system("touch ~/.pgpass && chmod 0600 ~/.pgpass")
    system("echo '*:*:*:#{database_username}:#{database_password}' > ~/.pgpass")
    system("PGPASSFILE=~/.pgpass pg_restore --no-owner -h #{database_hostname} -p 5432 -d #{database_name} /tmp/#{@file_name_last}")
    system("rm ~/.pgpass")
end

case action
#----------------------------------------------------------------------------------------
when "backup"
  backup
#-------------------------------------------------------------------------------------
when "download"
  download
#--------------------------------------------------------------------------------------------
when "restore_remote"
   restore_remote
#-----------------------------------------------------------------------------------------------
when "restore_localy"
  backup
  download
  restore_localy
else
      puts 'Action does\'n exist ' + action
end
