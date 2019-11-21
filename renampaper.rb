#!/usr/bin/env ruby
require "pdf-reader"
require "uri"
require 'open-uri'
require 'json'
require "rexml/document"
require 'optparse'


def moveAndRename(filename,newname,dir)
  if dir==nil
    dir=File.dirname(filename)
  end
  if File.directory?(dir)
    File.rename(filename,dir+'/'+newname+File.extname(filename))
    puts "To:\t"+dir+'/'+newname+File.extname(filename)
  else
    puts "#{dir} not a directory"
  end
end

def getDoi(x)
  return x.match /\b(10\.[0-9]{4,}(?:\.[0-9]+)*\/(?:(?![\"&\'])\S)+)\b/
end

def arXivInfo(arxivId)
  b='http://export.arxiv.org/api/query?id_list='+arxivId
  url = URI.parse(b)
  buffer = open(url,:proxy => nil).read
  doc = REXML::Document.new buffer
  xmlinfo = doc.elements["feed/entry"]
  info=""
  xmlinfo.elements.first(3).each("author") do |fc|
    # puts fc.elements["name"].first.to_s.split.last
    info+=fc.elements["name"].first.to_s.split.last
  end
  # puts xmlinfo.elements["updated"].first.to_s.split('-').first
  info += xmlinfo.elements["updated"].first.to_s.split('-').first

  # puts xmlinfo.elements["title"].first.to_s.split.join('_')
  info += xmlinfo.elements["title"].first.to_s.split.join('_')
  # puts info
  return info
end

def doiInfo(doi)
  uri = URI.parse("https://doi.org/#{doi}")
  buffer = open(uri,"Accept" => "application/vnd.citationstyles.csl+json",:proxy => nil).read
  result = JSON.parse(buffer)
  info = ""
  result["author"].first(3).each do |i|
    # puts i["family"]
    info+=i["family"]
  end
  # puts result["published-online"]["date-parts"][0][0]
  year = (result["published-print"]||result["published-online"])["date-parts"][0][0]
  info+="#{year}"
  # puts result["title"].gsub(/<\/?[^>]*>/, "").gsub(" ","_")
  return info+result["title"].gsub(/<\/?[^>]*>/, "").gsub(" ","_")
end

OptionParser.new do |parser|
  parser.banner = "Usage: renamepaper.rb [options] file [dir]\n\n\trenames file and moves file to dir\
                                                            \n\tif dir is not set renames file in place\
                                                            \n\n\trenaming:\
                                                            \n\tfile ->dir/authorsFamilyNameYearTitle.pdf\n\n"
  parser.on("","--doi [doi]","renames file using doi") do |id|
    if ARGV[0]==nil
      puts "missing file to rename"
      exit(0)
    end
    if File.file?(ARGV[0])
      puts "From:\t#{ARGV[0]}"
      # puts doiInfo(id)
      moveAndRename(ARGV[0],doiInfo(id),ARGV[1])
    else
      puts "#{ARGV[0]} not a file"
    end
    exit(0)
  end
  parser.on("","--arxiv [arXiv id]","renames file using arXiv id") do |id|
    if ARGV[0]==nil
      puts "missing file to rename"
      exit(0)
    end
    if File.file?(ARGV[0])
      puts "From:\t#{ARGV[0]}"
      # puts doiInfo(id)
      moveAndRename(ARGV[0],arXivInfo(id),ARGV[1])
    else
      puts "#{ARGV[0]} not a file"
    end
    exit(0)
  end
end.parse!

filename=ARGV[0]
if File.file?(filename)
  puts "From:\t"+filename
  reader = PDF::Reader.new(filename)
  doi=nil
  arxiv=nil
  # puts  filename
  for _ , i in reader.info
    if i =~ /\b(10\.[0-9]{4,}(?:\.[0-9]+)*\/(?:(?![\"&\'])\S)+)\b/
      doi = getDoi(i)
    end
  end
  if doi==nil
    content=reader.pages.first.raw_content
    if content.match(/arXiv/)
      arxiv = reader.pages.first.raw_content.match /(\d{4}\.\d{4,5}|[a-z\-]*(\.[A-Z]{2})?\/\d{7})(v\d)?/
    end
    if arxiv!=nil
      puts arxiv
      # puts arXivInfo(arxiv[1])
      moveAndRename(filename,arXivInfo(arxiv[1]),ARGV[1])
      puts "used arxiv"
      exit(0)
    end
    if reader.pages.first.text =~ /\b(10\.[0-9]{4,}(?:\.[0-9]+)*\/(?:(?![\"&\'])\S)+)\b/
      doi = getDoi(reader.pages.first.text)
      puts doi
      moveAndRename(filename,doiInfo(doi),ARGV[1])
      puts "doi from first page"
      exit(0)
    end
  else
    puts doi
    # puts doiInfo(doi)
    moveAndRename(filename,doiInfo(doi),ARGV[1])
    puts "used doi"
    exit(0)
  end
  if filename =~ /Rev/
    doi = "10.1103/"+File.basename(filename,".pdf")
    moveAndRename(filename,doiInfo(doi),ARGV[1])
    puts "used doi from file name"
    exit(0)
  end
else
  puts "fail #{ARGV[0]} not a file"
end
