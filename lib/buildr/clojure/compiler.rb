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
      
      def compile(sources, target, dependencies) #:nodoc:
        check_options options, OPTIONS
        
        fail 'Are we forgetting something? CLOJURE_HOME not set.' unless Cljc.clojure_home
        
        source_paths = sources.select { |source| File.directory?(source) }
        
        options[:libs] ||= source_paths.map { |path| detect_namespaces(path, []) }.flatten
        
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
        
        recompiled = false
        options[:libs].each do |ns|
          src = ns.gsub('.', '/')
          found = false
          
          source_paths.each do |s_path|
            orig = File.expand_path(src + '.clj', s_path)
            
            if File.exists? orig
              fail "Found duplicate namespace across multiple source dirs: #{ns}" if found
              found = true
              
              # I would like to run this all in the same VM, but RJB isn't cooperating
              file File.expand_path(src + '__init.class', target) => orig do
                unless recompiled
                  recompiled = true
                  
                  cmd = 'java ' + cmd_args.join(' ')
                  trace cmd
                  system cmd or fail 'Failed to compile. See errors above.'
                end
              end.invoke
            end
          end
        end
        
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
      
      def detect_namespaces(path, ns)
        back = []
        
        Dir.foreach path do |fname|
          unless fname == '.' or fname == '..'
            fullname = File.expand_path(fname, path)
            
            if fname =~ /^(.+)\.clj$/
              back << (ns + [$1]).join('.')
            elsif File.directory? fullname
              back << detect_namespaces(fullname, ns + [fname])
            end
          end
        end
        
        back
      end
      
      def copy_remainder(path, target, ns, done)
        Dir.foreach path do |fname|
          unless fname == '.' or fname == '..'
            fullname = File.expand_path(fname, path)
            
            if fname =~ /^(.+)\.clj$/
              fullns = if ns.size > 0 then ns.join('.') + '.' else '' end + $1
              
              unless done.include? fullns
                dest_dir = target + if ns.size > 0 then File::SEPARATOR + ns.join(File::SEPARATOR) else '' end
                
                file dest_dir + File::SEPARATOR + fname => fullname do
                  mkdir dest_dir unless File.exists? dest_dir
                  cp fullname, dest_dir + File::SEPARATOR + fname
                end.invoke
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

Buildr::Compiler.compilers.unshift Buildr::Clojure::Cljc
