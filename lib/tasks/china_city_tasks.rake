# desc "Explaining what the task does"
# task :china_city do
#   # Task goes here
# end
require 'json'
require 'httparty'
require 'nokogiri'

task :generate_postal_codes do

  data = JSON.parse(File.read('db/china_city_areas_2016.08.21.json'))

  result = (data['cities'] + data['districts']).inject({}) do |r, item|
    unless item['postcode']
      text = item['text'].encode('gbk', 'utf-8')
      url = "http://www.ip138.com/post/search.asp?action=area2zip&area=#{CGI::escape(text)}"
      res = HTTParty.get(url)

      doc = Nokogiri::HTML(res.body)
      links = doc.css("center table .tdc2")
      if links.size > 2
        postcode = links[1].text.match /\d{6}/
        r[item['id']] = postcode
        p "#{item['text']} #{links[1].text} #{postcode}"
      else
        if item['text'] == '北市区'
          r[item['id']] = '071000'
          p "#{item['text']} 071000"
        else
          p "#{item['text']} #{item['id']} not found"
        end
      end
    else
      r[item['id']] = item['postcode']
    end
    r
  end

  File.open('db/postal_codes.json', 'w') do |f|
    f.write JSON.pretty_generate(result)
  end
end

task :generate_sf_support do

  sf_data = CSV.read('db/sf_china_cover.csv')

  result = sf_data.select.each_with_index{|i, index| i[6] && index != 0}
            .inject({}) do |r, i|
              if %w(北京 重庆 上海 天津).include? i[3]
                full_text = i[3] + "市" + i[4..6].join("")
              else
                full_text = i[3..6].join("")
              end
              r[full_text] = i[7] == '全境'
              r
            end

  File.open('db/sf_support.json', 'w') do |f|
    f.write JSON.pretty_generate(result)
  end

end

task :check do
  data = JSON.parse(File.read("db/china_city_areas_2016.08.21.json"))


  data['cities'].group_by{|i| i['id']}.each do |g, v| 
    if v.size > 1
      v.each do |i|
        p_id = d_id[0..1].ljust(6,'00')

        p_text = data['provinces'].find{|t| t['id'] == p_id}['text']

        p p_text + i['text']
      end
    end
  end

  p '--------'

  data['districts'].group_by{|i| i['id']}.each do |g, v| 
    if v.size > 1
      v.each do |i|
        d_id = i['id']
        p_id = d_id[0..1].ljust(6,'00')
        c_id = d_id[0..3].ljust(6,'00')

        p_text = data['provinces'].find{|t| t['id'] == p_id}['text']
        c_text = data['cities'].find{|t| t['id'] == c_id}['text']

        p p_text + c_text + i['text']
      end
    end
  end

end


task :fix_id do

  data = JSON.parse(File.read("db/china_city_areas_2016.08.15.json"))
  data['cities']
  .select{|i| !i['id'].end_with?('00')}
  .group_by{|i| i['id'][0..1]}
  .each do |group, values|
    values.each_with_index do |i, index|
      old_id = i['id']
      new_id = old_id[0..1] + (90-index-1).to_s + "00"

      puts "修改 #{i['text']} #{old_id} => #{new_id}"
      i['id'] = new_id

      district = data['districts'].find{|d| d['id'] == old_id}
      new_district_id = new_id[0..3] + old_id[-2..-1]
      puts "修改 #{district['text']} #{old_id} => #{new_district_id}"
      district['id'] = new_district_id

      streets = data['streets'].select{|s| s['id'].start_with?(old_id)}
      streets.each do |s|
        puts "修改 #{s['text']} #{s['id']} => #{s['id'].gsub(old_id, new_district_id)}"
        s['id'] = s['id'].gsub(old_id, new_district_id)
      end

    end
  end

  File.open('db/china_city_areas_2016.08.15.json', 'w') do |f|
    f.write JSON.pretty_generate(data)
  end

end


task :rebuild_code do
  data = JSON.parse(File.read('db/china_city_areas_2016.08.15.json'))
  sf_data = CSV.read('db/sf_china_cover.csv')

  provinces_map = data['provinces'].inject({}) do |r, i|
    r[i['id'][0..1]] = i['text']
    r
  end

  cities_map = data['cities'].inject({}) do |r, i|
    province_text = provinces_map[i['id'][0..1]]
    r[province_text.gsub(/[省|市]/, '')+" "+i['text']] = i['id'][0..3]
    r
  end

  districts_map = {}
  districts = sf_data.select{|i| i[5] && !i[6]}
              .group_by{|i| i[3].gsub(/[省|市]/, '')+" "+i[4]}
              .inject([]) do |r, (g, v)|
                city_code = cities_map[g]
                r += v.each_with_index.map do |i, index|
                  id = city_code+(index+1).to_s.rjust(2,'0')
                  text = i[5] 
                  full_text = g + " " + text
                  sf_support = i[7]
                  districts_map[full_text] = id
                  t = {'id' => id, 'text' => text, "sf_support" => i[7]}
                  p t
                  t
                end
                r
              end

  p "districts.size = #{districts.size}"

  streets = sf_data.select.each_with_index{|i, index| i[6] && index != 0}
            .group_by{|i| i[3].gsub(/[省|市]/, '')+" "+i[4]+" "+i[5]}
            .inject([]) do |r, (g, v)|
              if g=="山东 临沂市 苍山县"
                g = "山东 临沂市 苍山县（兰陵县）"
              end
              district_code = districts_map[g]
              r += v.each_with_index.map do |i, index|
                p i
                id = district_code+(index+1).to_s.rjust(3,'0')
                text = i[6]
                sf_support = i[7]
                t = {'id' => id, 'text' => text, "sf_support" => i[7]}
                p t
                t
              end
              r
            end

  p "streets.size = #{streets.size}"

  new_data = {
    provinces: data['provinces'],
    cities: data['cities'],
    districts: districts,
    streets: streets
  }

  File.open('db/china_city_areas_2016.08.21.json', 'w') do |f|
    f.write JSON.pretty_generate(new_data)
  end

end

task :console do
  binding.pry
end
