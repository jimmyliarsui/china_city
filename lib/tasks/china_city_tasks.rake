# desc "Explaining what the task does"
# task :china_city do
#   # Task goes here
# end
require 'json'
require 'httparty'
require 'nokogiri'

task :generate_postal_codes do

  data = JSON.parse(File.read('db/china_city_areas_2016.08.15.json'))

  result = (data['cities'] + data['districts']).inject({}) do |r, item|
    unless item['postcode']
      text = item['text'].encode('gb2312', 'utf-8')
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

  result = ChinaUnit.each(3).inject({}) do |r, street|
    street_unit = ChinaUnit.new(street['id'])
    f = street_unit.full_name
    if street['support_sf'] == true
      r[f] = true
      p f
    end
    r
  end

  File.open('db/sf_support.json', 'w') do |f|
    f.write JSON.pretty_generate(result)
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
