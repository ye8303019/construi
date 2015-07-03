require 'construi/image'

module Construi

  class Container
    private_class_method :new

    def initialize(container)
      @container = container
    end

    def id
      @container.id
    end

    def delete
      @container.delete
    end

    def attach_stdout
      @container.attach(:stream => true, :logs => true) { |s, c| puts c; $stdout.flush }
      true
    rescue Docker::Error::TimeoutError
      puts 'Failed to attach to stdout'.yellow
      false
    end

    def commit
      Image.wrap(@container.commit)
    end

    def run
      @container.start
      attached = attach_stdout
      status_code = @container.wait['StatusCode']

      puts @container.logs(:stdout => true) unless attached

      raise Error, "Cmd returned status code: #{status_code}" unless status_code == 0

      commit
    end

    def ==(other)
      other.is_a? Container and id == other.id
    end

    def self.create(image, cmd, options = {})
      env = options[:env] || []
      privileged = options[:privileged] || false

      host_config = {
        'Binds' => ["#{Dir.pwd}:/var/workspace"],
        'Privileged' => privileged
      }

      wrap Docker::Container.create(
        'Cmd' => cmd.split,
        'Image' => image.id,
        'Env' => env,
        'Tty' => false,
        'WorkingDir' => '/var/workspace',
        'HostConfig' => host_config)
    end

    def self.wrap(container)
      new container
    end

    def self.use(image, cmd, options = {})
      container = create image, cmd, options
      yield container
    ensure
      container.delete unless container.nil?
    end

    def self.run(image, cmd, options = {})
      use image, cmd, options, &:run
    end

    class Error < StandardError
    end

  end

end
