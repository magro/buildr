require 'buildr/core/project'
require 'buildr/core/common'
require 'buildr/core/compile'
require 'buildr/packaging'

module Buildr
  module Clojure
    class Cljc < Buildr::Compiler::Base
      class << self
        def clojure_home
          @home ||= ENV['CLOJURE_HOME']
        end
    
        def dependencies
          File.expand_path('clojure.jar', clojure_home)
        end
      end
      
      OPTIONS = [:libs]
      
      Java.classpath << dependencies
      
      specify :language => :clojure, :sources => :clojure, :source_ext => :clj,
              :target => 'classes', :target_ext => 'class', :packaging => :jar
      
      def initialize(project, options)
        super
        
        options[:libs] ||= []
        
        Java.classpath << project.path_to(:target, :clojure)
        Java.classpath << project.path_to(:source, :main, :clojure)
      end
      
      def compile(sources, target, dependencies) #:nodoc:
        check_options options, OPTIONS
        
        Java.load
        Java.java.lang.System.setProperty('clojure.compile.path', File.expand_path(target))
        Java.clojure.lang.Compile.main(options[:libs].to_java(Java.java.lang.String))
      end
    end
  end
end

Buildr::Compiler.compilers << Buildr::Clojure::Cljc
