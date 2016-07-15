#!/usr/bin/env ruby

require 'rubygems'
require 'net/ssh'
require 'shellwords'
require 'pry'
require 'uri'

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

@dbhostname_cmd = "config:get #{remote_app_name[1]} DATABASE_HOSTNAME"
@dbname_cmd = "config:get #{remote_app_name[1]} DATABASE_NAME"
@dbpass_cmd = "config:get #{remote_app_name[1]} DATABASE_PASSWORD"
@dbusername_cmd = "config:get #{remote_app_name[1]} DATABASE_USERNAME"
@file_name = "db_backup.#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.sqlc"
@dburl_cmd = "config:get #{remote_app_name[1]} DATABASE_URL"


begin
  ssh = Net::SSH.start(@hostname, @username)
  url = (ssh.exec!(@dburl_cmd))
  ssh.close
  puts url
end

if url.nil? || url.empty?


  url = URI.parse(url.strip)
    database_hostname = url.host
    database_name = url.path[1..-1]
    database_password = url.password.gsub(/\n/,"").shellescape
    database_username = url.user
    puts 'database_hostname   ' + database_hostname
    puts 'database_name   ' + database_name
    puts 'database_password   ' + database_password
    puts 'database_username   ' +  database_username
    puts "tratatat"
else

begin
    ssh = Net::SSH.start(@hostname, @username)
    database_hostname = (ssh.exec!(@dbhostname_cmd)).gsub(/\n/,"").shellescape
    database_name = (ssh.exec!(@dbname_cmd)).gsub(/\n/,"").shellescape    
    database_password = (ssh.exec!(@dbpass_cmd)).gsub(/\n/,"").shellescape
    database_username = (ssh.exec!(@dbusername_cmd)).gsub(/\n/,"").shellescape
    ssh.close
  rescue
    puts "Unable to connect to #{@hostname} using #{@username}/#{password}"
end
end

case action
#----------------------------------------------------------------------------------------
when "backup"

  puts 'backuping process'
  @mkdir_cmd = "mkdir -p #{@backups_path_remote}"
  @backupdb_cmd = "PGPASSWORD=#{database_password} pg_dump -U #{database_username} -h #{database_hostname} #{database_name} -Fc --file=#{@backups_path_remote}/#{@file_name}"

begin
  ssh = Net::SSH.start(@hostname, @ubuntu_user)
    backups_path = ssh.exec!(@mkdir_cmd)
    backup = ssh.exec!(@backupdb_cmd)
    ssh.close
    puts 'end backup process'
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
   
    @pgpass_cmd = "touch ~/.pgpass && chmod 0600 ~/.pgpass"
    @credentials_cmd = "echo '*:*:*:#{database_username}:#{database_password}' > ~/.pgpass"
    @db_restore_cmd = "PGPASSFILE=~/.pgpass pg_restore --no-owner -h #{database_hostname} -p 5432 -d #{database_name} #{file_name_last}"
    @rmpgpass_cmd = "rm ~/.pgpass"
begin
  ssh = Net::SSH.start(@hostname, @ubuntu_user)
    pg_pass = ssh.exec!(@pgpass_cmd)
    db_credentials = ssh.exec!(@credentials_cmd)
    backups_path = ssh.exec!(@last_backup_cmd)
    file_name_last = backups_path.split[-1]
    restore_db = ssh.exec!(@bd_restore_cmd)
    rmpgpass = ssh.exec!(@rmpgpass_cmd)
    ssh.close
end
else
  puts 'Action does'n exist ' + action

end
