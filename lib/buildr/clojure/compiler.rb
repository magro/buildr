require 'buildr/core/project'
require 'buildr/core/common'
require 'buildr/core/compile'
require 'buildr/packaging'

require 'buildr/java/commands'

module Buildr
  module Clojure
    class Cljc < Buildr::Compiler::Base
      class << self
        def clojure_home
          @home ||= ENV['CLOJURE_HOME']
        end
      end
      
      OPTIONS = [:libs]
      
      specify :language => :clojure, :sources => :clojure, :source_ext => :clj,
              :target => 'classes', :target_ext => 'class', :packaging => :jar
      
      def initialize(project, options)
        super
        
        options[:libs] ||= []
      end
      
      def compile(sources, target, dependencies) #:nodoc:
        check_options options, OPTIONS
        
        source_paths = sources.select { |source| File.directory?(source) }
        cp = dependencies + source_paths + [
          File.expand_path('clojure.jar', Cljc.clojure_home)
        ]
        cp_str = inner_classpath_from(cp).join(File::PATH_SEPARATOR) + 
                 File::PATH_SEPARATOR + File.expand_path(target)
        
        cmd_args = [
          '-classpath', "'#{cp_str}'",
          "-Dclojure.compile.path='#{File.expand_path(target)}'",
          'clojure.lang.Compile'
        ] + options[:libs]
        
        trace "Target: #{target}"
        trace "Sources: [ #{sources.join ', '} ]"
        
        cmd = 'java ' + cmd_args.join(' ')
        trace cmd
        system cmd
        
        source_paths.each do |path|
          copy_remainder(path, File.expand_path(target), [], options[:libs])
        end
      end
      
    private
    
      def inner_classpath_from(cp)
        Buildr.artifacts(cp.map(&:to_s)).map do |t| 
          task(t).invoke
          File.expand_path t
        end
      end
      
      def copy_remainder(path, target, ns, done)
        Dir.foreach path do |fname|
          unless fname == '.' or fname == '..'
            fullname = File.expand_path(fname, path)
            
            if fname =~ /^(.+)\.clj$/
              unless done.include?(ns.join('.') + '.' + $1)
                dest_dir = target + File::SEPARATOR + ns.join(File::SEPARATOR)
                
                mkdir dest_dir unless File.exists? dest_dir
                
                cp fullname, dest_dir + File::SEPARATOR + fname
              end
            elsif File.directory? fullname
              copy_remainder(fullname, target, ns + [fname], done)
            end
          end
        end
      end
    end
  end
end

Buildr::Compiler.compilers << Buildr::Clojure::Cljc
