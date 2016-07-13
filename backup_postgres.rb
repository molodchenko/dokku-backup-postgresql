#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'shellwords'
require 'pry'

action = ARGV[0]

remote_name = "dokku"
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

@username = "#{remote_name}"
@hostname = "#{parsed_url[1]}"

@dbhostname = "config:get #{remote_app_name[1]} DATABASE_HOSTNAME"
@dbname = "config:get #{remote_app_name[1]} DATABASE_NAME"
@dbpass = "config:get #{remote_app_name[1]} DATABASE_PASSWORD"
@dbusername = "config:get #{remote_app_name[1]} DATABASE_USERNAME"


begin
    ssh = Net::SSH.start(@hostname, @username)
    database_hostname = (ssh.exec!(@dbhostname)).gsub(/\n/,"").shellescape
    database_name = (ssh.exec!(@dbname)).gsub(/\n/,"").shellescape    
    database_password = (ssh.exec!(@dbpass)).gsub(/\n/,"").shellescape
    database_username = (ssh.exec!(@dbusername)).gsub(/\n/,"").shellescape
    file_name = "db_backup.#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.sqlc"
    ssh.close
  rescue
    puts "Unable to connect to #{@hostname} using #{@username}/#{password}"
end

case action
#----------------------------------------------------------------------------------------
when "backup"
  @mkdir = "mkdir -p #{@backups_path_remote}"
  @backupdb = "PGPASSWORD=#{database_password} pg_dump -U #{database_username} -h #{database_hostname} #{database_name} -Fc --file=#{@backups_path_remote}/#{file_name}"

begin
  ssh = Net::SSH.start(@hostname, @ubuntu_user)
    backups_path = ssh.exec!(@mkdir)
    backup = ssh.exec!(@backupdb)
    ssh.close
end

#-------------------------------------------------------------------------------------
when "download"

begin
    ssh = Net::SSH.start(@hostname, @ubuntu_user)
    backups_path = ssh.exec!(@last_backup)
    ssh.close
    file_name_last = backups_path.split[-1]
    exec("scp #{@ubuntu_user}@#{@hostname}:#{@backups_path_remote}/#{file_name_last} /tmp")
    puts file_name_last
end

#--------------------------------------------------------------------------------------------
when "restore"
   
    @pgpass = "touch ~/.pgpass && chmod 0600 ~/.pgpass"
    @credentials = "echo '*:*:*:#{database_username}:#{database_password}' > ~/.pgpass"
    @db_restore = "PGPASSFILE=~/.pgpass pg_restore --no-owner -h #{database_hostname} -p 5432 -d #{database_name} #{file_name_last}"
    @rmpgpass = "rm ~/.pgpass"
begin
  ssh = Net::SSH.start(@hostname, @ubuntu_user)
    pg_pass = ssh.exec!(@pgpass)
    db_credentials = ssh.exec!(@credentials)
    backups_path = ssh.exec!(@last_backup)
    file_name_last = backups_path.split[-1]
    restore_db = ssh.exec!(@bd_restore)
    rmpgpass = ssh.exec!(@rmpgpass)
    ssh.close
end
end


