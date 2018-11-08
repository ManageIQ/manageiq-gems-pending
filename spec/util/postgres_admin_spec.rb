require "fileutils"
require "util/postgres_admin"

describe PostgresAdmin do
  let(:base_backup_file) { File.expand_path(File.join('data', 'pg_backup.tar.gz'), File.dirname(__FILE__)) }
  let(:pg_dump_file)     { File.expand_path(File.join('data', 'pg_dump.gz'), File.dirname(__FILE__)) }

  describe ".restore", :if => RSpec.configuration.with_postgres_specs do
    include_context "Database Restore Validation Helpers"

    context "with a pg_dump file" do
      let(:dbname) { "pg_dump_restore_of_simple_db" }

      it "restores all of the tables to the new database name" do
        restore_opts = RestoreHelper.default_restore_dump_opts.dup
        restore_opts[:dbname] = dbname
        PostgresAdmin.restore(restore_opts)

        expect(author_count).to eq(2)
        expect(book_count).to   eq(3)
      end
    end

    context "with a pg_dump file from a pipe" do
      let(:dbname)    { "pg_dump_restore_of_simple_db_from_pipe" }
      let(:fifo_path) { Pathname.new(Dir::Tmpname.create("") {}) }

      after { FileUtils.rm_rf(fifo_path) if File.exist?(fifo_path) }

      it "restores all of the tables to the new database name" do
        expect(PostgresAdmin).to receive(:pg_dump_file?).and_return(true)

        File.mkfifo(fifo_path)
        restore_opts = RestoreHelper.default_restore_dump_opts.dup
        restore_opts[:dbname]     = dbname
        restore_opts[:local_file] = fifo_path

        thread = Thread.new { IO.copy_stream(RestoreHelper::PG_DUMPFILE, fifo_path) }
        PostgresAdmin.restore(restore_opts)
        thread.join

        expect(author_count).to eq(2)
        expect(book_count).to   eq(3)
      end
    end

    context "with a pg_basebackup file" do
      # can't change this name, since it is just a import of the tar directory
      # that was made.  We want to change this above, however, so that we make
      # sure the database is restored via the dump properly, incase the order
      # of these specs is swapped.
      let(:dbname) { "simple_db" }

      it "restores all of the tables to the new database name" do
        set_spec_env_for_postgres_admin_basebackup_restore
        PostgresAdmin.restore(RestoreHelper.restore_backup_opts)

        expect(author_count).to eq(2)
        expect(book_count).to   eq(3)
      end
    end

    # Note, we aren't actually prefetching the magic here, but this is mean to
    # simulate that an override works as expected.  We are stubbing the the
    # restore calls here, so just making sure the logic works.
    context "'pre-fetching' magic number" do
      let(:dummy_base_opts) { { :local_file => "foo" } }

      # Please note:  These `.expect` calls are VERY IMPORTANT validations
      # happening, as we want to prioritize the `:backup_type` option over the
      # calls the `.pg_dump_file?` and `.base_backup_file?` when possible.
      before do
        expect(PostgresAdmin).to receive(:pg_dump_file?).never
        expect(PostgresAdmin).to receive(:base_backup_file?).never
      end

      it "calls `.restore_pg_dump` with :backup_type => :pgdump" do
        expect(PostgresAdmin).to receive(:restore_pg_dump).with(dummy_base_opts)
        PostgresAdmin.restore(dummy_base_opts.merge(:backup_type => :pgdump))
      end

      it "calls `.restore_pg_basebackup` with :backup_type => :basebackup" do
        expect(PostgresAdmin).to receive(:restore_pg_basebackup).with("foo")
        PostgresAdmin.restore(dummy_base_opts.merge(:backup_type => :basebackup))
      end
    end
  end

  describe ".base_backup_file?" do
    it "properly identifies compressed backup dirs" do
      expect(described_class.base_backup_file?(base_backup_file)).to be true
    end

    it "does not accept compressed pg_dump formats" do
      expect(described_class.base_backup_file?(pg_dump_file)).to be false
    end
  end

  describe ".pg_dump_file?" do
    it "properly identifies compressed pg_dump formats" do
      expect(described_class.pg_dump_file?(pg_dump_file)).to be true
    end

    it "does not accept compressed backup dirs" do
      expect(described_class.pg_dump_file?(base_backup_file)).to be false
    end
  end

  describe ".backup_pg_dump" do
    subject             { described_class }

    let(:local_file)    { nil }
    let(:expected_opts) { {} }
    let(:expected_args) { default_args }
    let(:default_args) do
      {
        :no_password => nil,
        :format      => "c",
        :file        => local_file,
        nil          => nil
      }
    end

    before do
      expect(subject).to receive(:runcmd_with_logging).with("pg_dump", expected_opts, expected_args)
    end

    context "with empty args" do
      it "runs the command and returns the :local_file opt" do
        expect(subject.backup_pg_dump({})).to eq(local_file)
      end
    end

    context "with :local_file in opts" do
      let(:local_file)    { "/some/path/to/pg.dump" }
      let(:expected_opts) { { :local_file => local_file } }

      it "runs the command and returns the :local_file opt" do
        opts = expected_opts
        expect(subject.backup_pg_dump(opts)).to eq(local_file)
      end
    end

    context "with :local_file and :dbname in opts" do
      let(:local_file)    { "/some/path/to/pg.dump" }
      let(:expected_opts) { { :local_file => local_file } }
      let(:expected_args) { default_args.merge(nil => "mydb") }

      it "runs the command and returns the :local_file opt" do
        opts = expected_opts.merge(:dbname => "mydb")
        expect(subject.backup_pg_dump(opts)).to eq(local_file)
      end
    end

    context "with :local_file, :dbname, :username, and :password in opts" do
      let(:local_file)    { "/some/path/to/pg.dump" }
      let(:expected_opts) do
        {
          :local_file => local_file,
          :username   => "admin",
          :password   => "smartvm"
        }
      end
      let(:expected_args) do
        default_args.merge(nil => "mydb", :username => "admin")
      end

      it "runs the command and returns the :local_file opt" do
        opts = expected_opts.merge(:dbname => "mydb")
        expect(subject.backup_pg_dump(opts)).to eq(local_file)
      end
    end

    context "with :local_file, :dbname and :hostname in opts" do
      let(:local_file)    { "/some/path/to/pg.dump" }
      let(:expected_opts) { { :local_file => local_file, :hostname => 'foo' } }
      let(:expected_args) { default_args.merge(nil => "mydb", :host => 'foo') }

      it "runs the command and returns the :local_file opt" do
        opts = expected_opts.merge(:dbname => "mydb")
        expect(subject.backup_pg_dump(opts)).to eq(local_file)
      end
    end

    shared_examples "for splitting multi value arg" do |arg_type|
      arg_as_cmdline_opt = "-#{'-' if arg_type.size > 1}#{arg_type}"

      let(:local_file) { "/some/path/to/pg.dump" }

      context "with #{arg_as_cmdline_opt} as a single value" do
        let(:expected_opts) { { :local_file => local_file } }
        let(:expected_args) do
          default_args.to_a << [arg_type, "value1"]
        end

        it "runs the command and returns the :local_file opt" do
          opts = expected_opts.merge(arg_type => "value1")
          expect(subject.backup_pg_dump(opts)).to eq(local_file)
        end
      end

      context "with #{arg_as_cmdline_opt} as a single value array" do
        let(:expected_opts) { { :local_file => local_file } }
        let(:expected_args) do
          default_args.to_a << [arg_type, "value1"]
        end

        it "runs the command and returns the :local_file opt" do
          opts = expected_opts.merge(arg_type => ["value1"])
          expect(subject.backup_pg_dump(opts)).to eq(local_file)
        end
      end

      context "with #{arg_as_cmdline_opt} as a multi value array" do
        let(:expected_opts) { { :local_file => local_file } }
        let(:expected_args) do
          default_args.to_a << [arg_type, "value1"] << [arg_type, "value2"]
        end

        it "runs the command and returns the :local_file opt" do
          opts = expected_opts.merge(arg_type => %w[value1 value2])
          expect(subject.backup_pg_dump(opts)).to eq(local_file)
        end
      end
    end

    context "with :local_file, :t in opts" do
      include_examples "for splitting multi value arg", :t
    end

    context "with :local_file, :table in opts" do
      include_examples "for splitting multi value arg", :table
    end

    context "with :local_file, :T in opts" do
      include_examples "for splitting multi value arg", :T
    end

    context "with :local_file, :exclude_table in opts" do
      include_examples "for splitting multi value arg", :exclude_table
    end

    context "with :local_file, :exclude-table in opts" do
      include_examples "for splitting multi value arg", :"exclude-table"
    end

    context "with :local_file, :exclude-table-data in opts" do
      include_examples "for splitting multi value arg", :"exclude-table-data"
    end

    context "with :local_file, :exclude_table_data in opts" do
      include_examples "for splitting multi value arg", :exclude_table_data
    end

    context "with :local_file, :t in opts" do
      include_examples "for splitting multi value arg", :n
    end

    context "with :local_file, :table in opts" do
      include_examples "for splitting multi value arg", :schema
    end

    context "with :local_file, :T in opts" do
      include_examples "for splitting multi value arg", :N
    end

    context "with :local_file, :exclude-table in opts" do
      include_examples "for splitting multi value arg", :"exclude-schema"
    end

    context "with :local_file, :exclude_table in opts" do
      include_examples "for splitting multi value arg", :exclude_schema
    end
  end

  context "ENV dependent" do
    after do
      ENV.delete_if { |k, _| k.start_with?("APPLIANCE") }
    end

    [%w(data_directory     APPLIANCE_PG_DATA            /some/path      true),
     %w(service_name       APPLIANCE_PG_SERVICE         postgresql          ),
     %w(package_name       APPLIANCE_PG_PACKAGE_NAME    postgresql-server   ),
     %w(template_directory APPLIANCE_TEMPLATE_DIRECTORY /some/path      true),
     %w(mount_point        APPLIANCE_PG_MOUNT_POINT     /mount/point    true)
    ].each do |method, var, value, pathname_required|
      it method.to_s do
        ENV[var] = value
        result = described_class.public_send(method)
        if pathname_required
          expect(result.join("abc/def").to_s).to eql "#{value}/abc/def"
        else
          expect(result).to eql value
        end
      end
    end

    it ".logical_volume_path" do
      expect(described_class.logical_volume_path.to_s).to eql "/dev/vg_data/lv_pg"
    end

    context "with a data directory" do
      around do |example|
        Dir.mktmpdir do |dir|
          ENV["APPLIANCE_PG_DATA"] = dir
          example.run
        end
      end

      describe ".initialized?" do
        it "returns true with files in the data directory" do
          FileUtils.touch("#{ENV["APPLIANCE_PG_DATA"]}/somefile")
          expect(described_class.initialized?).to be true
        end

        it "returns false without files in the data directory" do
          expect(described_class.initialized?).to be false
        end
      end

      describe ".local_server_in_recovery?" do
        it "returns true when recovery.conf exists" do
          FileUtils.touch("#{ENV["APPLIANCE_PG_DATA"]}/recovery.conf")
          expect(described_class.local_server_in_recovery?).to be true
        end

        it "returns false when recovery.conf does not exist" do
          expect(described_class.local_server_in_recovery?).to be false
        end
      end

      describe ".local_server_status" do
        let(:service) { double("postgres service") }

        before do
          ENV["APPLIANCE_PG_SERVICE"] = "postgresql"
          allow(LinuxAdmin::Service).to receive(:new).and_return(service)
        end

        context "when the server is running" do
          before do
            allow(service).to receive(:running?).and_return(true)
          end

          it "returns a running status and primary with no recovery file" do
            expect(described_class.local_server_status).to eq("running (primary)")
          end

          it "returns a running status and standby with a recovery file" do
            FileUtils.touch("#{ENV["APPLIANCE_PG_DATA"]}/recovery.conf")
            expect(described_class.local_server_status).to eq("running (standby)")
          end
        end

        context "when the server is not running" do
          before do
            allow(service).to receive(:running?).and_return(false)
          end

          it "returns initialized and stopped if it is initialized" do
            FileUtils.touch("#{ENV["APPLIANCE_PG_DATA"]}/somefile")
            expect(described_class.local_server_status).to eq("initialized and stopped")
          end

          it "returns not initialized if the data directory is empty" do
            expect(described_class.local_server_status).to eq("not initialized")
          end
        end
      end
    end
  end
end
