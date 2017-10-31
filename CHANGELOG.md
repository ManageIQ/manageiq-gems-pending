# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 72 ending 2017-10-30

### Added
- Log timings on exception in outermost block [(#255)](https://github.com/ManageIQ/manageiq-gems-pending/pull/255)

### Fixed
- Use pg_basebackup for database backups [(#302)](https://github.com/ManageIQ/manageiq-gems-pending/pull/302)
- Allow ipv6 address as dns when setting static ipv4  [(#285)](https://github.com/ManageIQ/manageiq-gems-pending/pull/285)

## Unreleased as of Sprint 71 ending 2017-10-16

### Fixed
- Pass a string to mount_point_exists? method [(#286)](https://github.com/ManageIQ/manageiq-gems-pending/pull/286)
- Must give password to set db in cli [(#281)](https://github.com/ManageIQ/manageiq-gems-pending/pull/281)
- Internal database must be set with dbdisk option in ap and in cli [(#277)](https://github.com/ManageIQ/manageiq-gems-pending/pull/277)
- Specify rhel7 as the scap security guide platform [(#275)](https://github.com/ManageIQ/manageiq-gems-pending/pull/275)

## Unreleased as of Sprint 69 ending 2017-09-18

### Fixed
- Platform
  - Improve the grammar of the db connection error message [(#272)](https://github.com/ManageIQ/manageiq-gems-pending/pull/272)
  - Set v2_key file permissions to 0400 after create or fetch [(#270)](https://github.com/ManageIQ/manageiq-gems-pending/pull/270)
  - Change log_hashes to log hash-like objects properly [(#268)](https://github.com/ManageIQ/manageiq-gems-pending/pull/268)

## Unreleased as of Sprint 68 ending 2017-09-04

### Added
- Console
  - Add support for the external auth domain user attribute [(#250)](https://github.com/ManageIQ/manageiq-gems-pending/pull/250)

## Unreleased as of Sprint 67 ending 2017-08-21

### Fixed
- Platform
  - Corrected error message to suggest valid option - Reset Configured Database [(#258)](https://github.com/ManageIQ/manageiq-gems-pending/pull/258)
  - Allow httpd password to have dollar sign in it [(#257)](https://github.com/ManageIQ/manageiq-gems-pending/pull/257)
  - Fix restart network error when set host name in pure ipv6 network [(#256)](https://github.com/ManageIQ/manageiq-gems-pending/pull/256)
