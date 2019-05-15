# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Hammer-6

### Added
- Add put_file method [(#426)](https://github.com/ManageIQ/manageiq-gems-pending/pull/426)

## Unreleased as of Sprint 107 ending 2019-03-18

### Added
- Remove PG gem dependency versioning [(#423)](https://github.com/ManageIQ/manageiq-gems-pending/pull/423)
- Change pg_basebackup xlog-method option to wal-method [(#422)](https://github.com/ManageIQ/manageiq-gems-pending/pull/422)

## Hammer-1 - Released 2019-01-14

### Added
- Add :backup_type option to PostgresAdmin.restore [(#402)](https://github.com/ManageIQ/manageiq-gems-pending/pull/402)
- Add MiqSwiftStorage#download_single [(#400)](https://github.com/ManageIQ/manageiq-gems-pending/pull/400)
- [MiqFileStorage] Add #magic_number_for [(#401)](https://github.com/ManageIQ/manageiq-gems-pending/pull/401)
- Fixes to swift storage [(#410)](https://github.com/ManageIQ/manageiq-gems-pending/pull/410)
- Use Gem::Package for tar pg restore unpacking via download streaming [(#406)](https://github.com/ManageIQ/manageiq-gems-pending/pull/406)
- [MiqGenericMountSession] Support @byte_count in #download_single [(#395)](https://github.com/ManageIQ/manageiq-gems-pending/pull/395)
- [MiqFtpStorage] Support @byte_count in #download_single [(#396)](https://github.com/ManageIQ/manageiq-gems-pending/pull/396)
- Determine magic number without shellout [(#389)](https://github.com/ManageIQ/manageiq-gems-pending/pull/389)
- Handle pipes for pg_restore [(#390)](https://github.com/ManageIQ/manageiq-gems-pending/pull/390)
- [MiqS3Storage] Support @byte_count in #download_single [(#399)](https://github.com/ManageIQ/manageiq-gems-pending/pull/399)
- Add stdin option to shell_exec [(#382)](https://github.com/ManageIQ/manageiq-gems-pending/pull/382)
- DB Backups to Openstack Swift [(#371)](https://github.com/ManageIQ/manageiq-gems-pending/pull/371)
- Be more lenient for locked down ftp servers [(#384)](https://github.com/ManageIQ/manageiq-gems-pending/pull/384)
- MiqFileStorage interface and subclassing (with file splitting) [(#361)](https://github.com/ManageIQ/manageiq-gems-pending/pull/361)
- Adds MiqFtpLib [(#360)](https://github.com/ManageIQ/manageiq-gems-pending/pull/360)
-  Enables downloading backup file from S3 prior to running restore command [(#357)](https://github.com/ManageIQ/manageiq-gems-pending/pull/357)
- Add pg_dump support back to PostgresAdmin [(#351)](https://github.com/ManageIQ/manageiq-gems-pending/pull/351)
- Log timings on exception in outermost block [(#255)](https://github.com/ManageIQ/manageiq-gems-pending/pull/255)
- Use a constant mask for encrypted fields [(#377)](https://github.com/ManageIQ/manageiq-gems-pending/pull/377)
- Don't set empty ENV values for database dumps [(#378)](https://github.com/ManageIQ/manageiq-gems-pending/pull/378)
- Add support to send data on standard input when executing a command [(#379)](https://github.com/ManageIQ/manageiq-gems-pending/pull/379)

### Fixed
- [PostgresAdmin] Fix backup_type being ignored [(#405)](https://github.com/ManageIQ/manageiq-gems-pending/pull/405)
- Fixes some bugs with MiqS3Storage#download_single [(#397)](https://github.com/ManageIQ/manageiq-gems-pending/pull/397)
- Fixes and cleanup for MiqSwiftStorage [(#398)](https://github.com/ManageIQ/manageiq-gems-pending/pull/398)
- Changes to MiqPassword.sanitize_string to support URL encoded password. [(#373)](https://github.com/ManageIQ/manageiq-gems-pending/pull/373)
- Use correct variable name for PostgresAdmin [(#370)](https://github.com/ManageIQ/manageiq-gems-pending/pull/370)
- require net-ssh in MiqSshUtil [(#307)](https://github.com/ManageIQ/manageiq-gems-pending/pull/307)
- Use pg_basebackup for database backups [(#302)](https://github.com/ManageIQ/manageiq-gems-pending/pull/302)
- Allow ipv6 address as dns when setting static ipv4  [(#285)](https://github.com/ManageIQ/manageiq-gems-pending/pull/285)

### Removed
- Remove Debug Messages [(#359)](https://github.com/ManageIQ/manageiq-gems-pending/pull/359)

## Unreleased as of Sprint 99 ending 2018-11-19

### Added
- Remove util/miq-password [(#407)](https://github.com/ManageIQ/manageiq-gems-pending/pull/407)

## Gaprindashvili-6 - Released 2018-11-02

### Fixed
- Changes to MiqPassword.sanitize_string to support URL encoded password. [(#373)](https://github.com/ManageIQ/manageiq-gems-pending/pull/373)

## Unreleased as of Sprint 97 ending 2018-10-22

### Added
- Leverage run_session for SFTP [(#381)](https://github.com/ManageIQ/manageiq-gems-pending/pull/381)

## Gaprindashvili-3 - Released 2018-05-15

### Fixed
- Dont mess with pglogical from PostgresAdmin [(#336)](https://github.com/ManageIQ/manageiq-gems-pending/pull/336)
- Fixed to validate attributes before inserting into XML. [(#339)](https://github.com/ManageIQ/manageiq-gems-pending/pull/339)

## Gaprindashvili-2 released 2018-03-06

### Fixed
- Create an empty directory for pg_basebackup [(#331)](https://github.com/ManageIQ/manageiq-gems-pending/pull/331)
- Fix ENOENT error from backup_pg_compress [(#332)](https://github.com/ManageIQ/manageiq-gems-pending/pull/332)

## Gaprindashvili-1 - Released 2018-01-31

### Added
- Get the unique_set_size with other process info [(#317)](https://github.com/ManageIQ/manageiq-gems-pending/pull/317)
- Add support for the external auth domain user attribute [(#250)](https://github.com/ManageIQ/manageiq-gems-pending/pull/250)

### Fixed
- Pass a string to mount_point_exists? method [(#286)](https://github.com/ManageIQ/manageiq-gems-pending/pull/286)
- Must give password to set db in cli [(#281)](https://github.com/ManageIQ/manageiq-gems-pending/pull/281)
- Internal database must be set with dbdisk option in ap and in cli [(#277)](https://github.com/ManageIQ/manageiq-gems-pending/pull/277)
- Specify rhel7 as the scap security guide platform [(#275)](https://github.com/ManageIQ/manageiq-gems-pending/pull/275)
- Improve the grammar of the db connection error message [(#272)](https://github.com/ManageIQ/manageiq-gems-pending/pull/272)
- Set v2_key file permissions to 0400 after create or fetch [(#270)](https://github.com/ManageIQ/manageiq-gems-pending/pull/270)
- Change log_hashes to log hash-like objects properly [(#268)](https://github.com/ManageIQ/manageiq-gems-pending/pull/268)
- Corrected error message to suggest valid option - Reset Configured Database [(#258)](https://github.com/ManageIQ/manageiq-gems-pending/pull/258)
- Allow httpd password to have dollar sign in it [(#257)](https://github.com/ManageIQ/manageiq-gems-pending/pull/257)
- Fix restart network error when set host name in pure ipv6 network [(#256)](https://github.com/ManageIQ/manageiq-gems-pending/pull/256)
- Always use SSH in non-interactive mode [(#319)](https://github.com/ManageIQ/manageiq-gems-pending/pull/319)
- Add valid_encoding checking before inserting into xml object [(#318)](https://github.com/ManageIQ/manageiq-gems-pending/pull/318)
- Truncating log messages when they are too large [(#315)](https://github.com/ManageIQ/manageiq-gems-pending/pull/315)
- Fix require net/sftp for Users SSA [(#323)](https://github.com/ManageIQ/manageiq-gems-pending/pull/323)

## Initial changelog added
