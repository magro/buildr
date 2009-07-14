module Buildr
  module CC
    include Extension
    
    class << self
      def check_mtime(pattern, old_times)
        times = old_times
        changed = []
        
        Dir.glob pattern do |fname|
          if old_times[fname].nil? || old_times[fname] < File.mtime(fname)
            times[fname] = File.mtime fname
            changed << fname
          end
        end
        
        [times, changed]
      end
      
      def strip_filename(project, name)
        name.gsub project.base_dir + File::SEPARATOR, ''
      end
    end
    
    first_time do
      Project.local_task :cc
    end
    
    before_define do |project|
      project.task :cc => :compile do
        dirs = project.compile.sources.map(&:to_s)
        res = project.resources.sources.map(&:to_s)
        ext = Buildr::Compiler.select(project.compile.compiler).source_ext.map(&:to_s)
        
        res_tail = if res.empty? then '' else ",{#{res.join ','}}/**/*" end
        pattern = "{{#{dirs.join ','}}/**/*.{#{ext.join ','}}#{res_tail}}"
        
        times, _ = Buildr::CC.check_mtime pattern, {}     # establish baseline
        
        dir_names = (dirs + res).map { |file| Buildr::CC.strip_filename project, file }
        if dirs.length == 1
          info "Monitoring directory: #{dir_names.first}"
        else
          info "Monitoring directories: [#{dir_names.join ', '}]"
        end
        trace "Monitoring extensions: [#{ext.join ', '}]"
        
        while true
          sleep project.cc.frequency
          
          times, changed = Buildr::CC.check_mtime pattern, times
          unless changed.empty?
            info ''    # better spacing
            
            changed.each do |file|
              info "Detected changes in #{Buildr::CC.strip_filename project, file}"
            end
            
            project.task(:resources).reenable
            project.task(:resources).invoke
            
            project.task(:compile).reenable
            project.task(:compile).invoke
          end
        end
      end
    end
    
    def cc
      @cc ||= CCOptions.new
    end
    
    class CCOptions
      attr_writer :frequency
      
      def frequency
        @frequency ||= 0.2
      end
    end
  end
  
  class Project
    include CC
  end
end
