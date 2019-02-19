Recreating `pg_dump.gz` and `pg_backup.tar.gz`
==============================================

This document is used as a step by step guide to creating the `pg_dump.gz` and
`pg_backup.tar.gz` files found in `spec/util/data/`.

Both are done from a Vagrant appliance VM to more accurately represent the way
that these files would be generated.  Setting up an appliance is outside the
scope of this document, but it is assumed that you are using one to generate
these files and they will be copied off the VM once finished.

Also, you should shut down `evmserverd` prior to trying to run these commands.

**NOTE**:  In the console instructions sections below, `#` is used to denote
root privileges (not a comment), while `$` is just the login user.


`pg_dump.gz`
------------

1. Log into the appliance and open a console in the `vmdb` dir
  
  ```console
  $ vmdb
  $ sudo --shell
  # bin/rails c
  ```
  
2. Create a new "simple_db" using the steps below
  
  ```ruby
  irb(main):001:0> config = ActiveRecord::Base.configurations["production"].merge("database" => "simple_db")
  => {"adapter"=>"postgresql", "encoding"=>"utf8", "username"=>"root", "pool"=>5, "wait_timeout"=>5, "min_messages"=>"warning", "database"=>"simple_db", "host"=>"localhost", "password"=>"smartvm"}
  irb(main):002:0> ActiveRecord::Base.connection.create_database("simple_db", config)
  => #<PG::Result:0x00000008522e40 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):003:0> ActiveRecord::Base.establish_connection config
  => #<ActiveRecord::ConnectionAdapters::ConnectionPool:0x0000000841cde8 ...>
  irb(main):004:0> ActiveRecord::Base.connection.current_database
  => "simple_db"
  irb(main):005:0> ActiveRecord::Base.connection.create_table(:books) { |t| t.string :name; t.integer :author_id }
  => #<PG::Result:0x000000083b21f0 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):006:0> ActiveRecord::Base.connection.create_table(:authors) { |t| t.string :first_name; t.string :last_name }
  => #<PG::Result:0x00000008397670 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):008:0> class Book < ActiveRecord::Base; end
  => nil
  irb(main):009:0> class Author < ActiveRecord::Base; has_many :books; end
  => nil
  irb(main):010:0> Author.create(:first_name => "Author", :last_name => "One")
  => #<Author id: 1, first_name: "Author", last_name: "One">
  irb(main):011:0> Author.create(:first_name => "Author", :last_name => "Two")
  => #<Author id: 2, first_name: "Author", last_name: "Two">
  irb(main):012:0> Book.create(:name => "Book: One", :author_id => 1)
  => #<Book id: 1, name: "Book: One", author_id: 1>
  irb(main):013:0> Book.create(:name => "Book: Two", :author_id => 1)
  => #<Book id: 2, name: "Book: Two", author_id: 1>
  irb(main):014:0> Book.create(:name => "Book: Three", :author_id => 1)
  => #<Book id: 3, name: "Book: Three", author_id: 1>
  irb(main):015:0> Author.first.books.count
  => 3
  irb(main):016:0> Author.last.books.count
  => 0
  irb(main):017:0> exit
  ```
  
3. Dump the database to a file:
  
  ```console
  $ pg_dump --format c --file pg_dump.gz simple_db
  ```


`pg_backup.tar.gz`
------------------

1. Log into the appliance and drop the existing `vmdb_production` database
  
  ```console
  $ vmdb
  $ sudo --shell
  # DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rake db:drop
  ```
  
2. Open a irb console with `ActiveRecord` included
  
  ```console
  # irb -r active_record
  ```
  
3. Create a new "simple_db" using the steps below
  
  ```ruby
  irb(main):001:0> config = {"adapter"=>"postgresql", "encoding"=>"utf8", "username"=>"root", "pool"=>5, "wait_timeout"=>5, "min_messages"=>"warning", "database"=>"simple_db", "host"=>"localhost", "password"=>"smartvm"}
  => {"adapter"=>"postgresql", "encoding"=>"utf8", "username"=>"root", "pool"=>5, "wait_timeout"=>5, "min_messages"=>"warning", "database"=>"simple_db", "host"=>"localhost", "password"=>"smartvm"}
  irb(main):002:0> ActiveRecord::Base.connection.create_database("simple_db", config.merge("database" => "postgres"))
  => #<PG::Result:0x00000008522e40 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):003:0> ActiveRecord::Base.establish_connection config
  => #<ActiveRecord::ConnectionAdapters::ConnectionPool:0x0000000841cde8 ...>
  irb(main):004:0> ActiveRecord::Base.connection.current_database
  => "simple_db"
  irb(main):005:0> ActiveRecord::Base.connection.create_table(:books) { |t| t.string :name; t.integer :author_id }
  => #<PG::Result:0x000000083b21f0 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):006:0> ActiveRecord::Base.connection.create_table(:authors) { |t| t.string :first_name; t.string :last_name }
  => #<PG::Result:0x00000008397670 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>
  irb(main):008:0> class Book < ActiveRecord::Base; end
  => nil
  irb(main):009:0> class Author < ActiveRecord::Base; has_many :books; end
  => nil
  irb(main):010:0> Author.create(:first_name => "Author", :last_name => "One")
  => #<Author id: 1, first_name: "Author", last_name: "One">
  irb(main):011:0> Author.create(:first_name => "Author", :last_name => "Two")
  => #<Author id: 2, first_name: "Author", last_name: "Two">
  irb(main):012:0> Book.create(:name => "Book: One", :author_id => 1)
  => #<Book id: 1, name: "Book: One", author_id: 1>
  irb(main):013:0> Book.create(:name => "Book: Two", :author_id => 1)
  => #<Book id: 2, name: "Book: Two", author_id: 1>
  irb(main):014:0> Book.create(:name => "Book: Three", :author_id => 1)
  => #<Book id: 3, name: "Book: Three", author_id: 1>
  irb(main):015:0> Author.first.books.count
  => 3
  irb(main):016:0> Author.last.books.count
  => 0
  irb(main):017:0> exit
  ```
  
4. Backup the database to a file:
  
  ```console
  # mkdir pg_backup
  # pg_basebackup --no-password -z --format t --wal-method fetch --pgdata pg_backup
  # cp pg_backup/base.tar.gz /home/YOUR_USER/pg_backup.tar.gz
  # chown YOUR_USER:YOUR_USER pg_backup.tar.gz
  ```


TODO
----

* [ ] Update steps for `pg_backup.tar.gz` to clear out unecessary logs
