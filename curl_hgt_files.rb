#!/usr/bin/env ruby -wKU

# 

def curl_all_hgts
    list_file      = ENV["HOME"] + "/webapps/htdocs/DEM2CUT/dems/srtm_map_list.html"
    download_dir   = ENV["HOME"] + "/webapps/htdocs/DEM2CUT/dems/SRTM_90m_global/"
    # TODO: this would go a lot lot faster if I threaded this... -ETJ 19 Feb 2012
    
    # open list file and read it into lines    
    lines = IO.readlines( list_file)
    i = 0
    line_count = lines.length
    lines.each {|line| 
        
        # from each line, get a link filename
        link = line[%r{^\s*<li><a href="(.*)">(.*)<\/a></li>}, 1]
        next if not link
        local_file = download_dir+link[%r{.*/(.*?)$}, 1]
        # check and see if the file (or its uncompressed version)
        # is present in download_dir
        downloaded_files = [local_file, local_file[/(.*).zip/,1]]
        
        next if downloaded_files.any? { |e| File.exist? e }
        # if not, download the file
        # print  "curl #{link} -o #{local_file}\n"
        `curl #{link} -o #{local_file}`  
        puts "Completed #{i} of #{line_count}\n"
        i += 1
        break if i > 10
    }

    
    
    
end

if __FILE__ == $0
    curl_all_hgts()
end
