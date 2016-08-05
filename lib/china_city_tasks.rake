require 'json'
require 'csv'
require 'china_unit'

namespace :gem do

  desc '导入顺丰数据'
  task :update_data do
    data = CSV.read('db/sf_data.csv').select.each_with_index do |row, index|
      index!=0 and !row[6].nil?
    end.map{|i| i.slice(3..6) + [i[7]]}

    not_found = []

    origin_provinces = ChinaUnit::DATA["province"]
    provinces_map = {}
    provinces = data.group_by{|i| i[0]}.keys.uniq.map do |i|
      if %w(北京 重庆 上海 天津).include? i
        i += "市"
      end
      t = origin_provinces.find{|j| j['text'] == i}
      provinces_map[i] = t['id'][0..1]
      { 'id' => t['id'], 'text' => i }
    end.compact
    puts "provinces done"

    cities_map = {}
    cities = data.group_by{|i| [i[0],i[1]]}.keys.uniq{|i| i[0]+i[1]}.map do |i|
      u = i.join("")
      if city_should_fix.include? u
        i << i.last
        i[1] = "省直辖县级行政区划"
      end
      begin
        unit = ChinaUnit.find_by_names(i).last
      rescue ChinaUnitNotFoundError => e
        not_found << e.names + [e.level]
        next
      end

      cities_map[u] = unit.id[0..3]
      { 'id' => unit.id, 'text' => i.last, 'postcode' => unit.postcode }
    end.compact
    puts "cities done"

    districts_map = {}
    districts = data.group_by{|i| [i[0], i[1], i[2]]}.keys.uniq{|i| i.join('')}.map do |i|
      f = i[0..2].join("")
      u = i[0..1].join("")
      if city_should_fix.include? u
        i[2] = i[1]
        i[1] = "省直辖县级行政区划"
      end
      district_find = district_should_fix[f]
      if district_find
        districts_map[f] = district_find[0]
        { 'id' => district_find[0],
          'text' => i,
          'postcode' => district_find[1] }
      else
        begin
          unit = ChinaUnit.find_by_names(i).last
        rescue ChinaUnitNotFoundError => e
          not_found << e.names + [e.level]
          next
        end
        districts_map[f] = unit.id
        { 'id' => unit.id, 'text' => i.last, 'postcode': unit.postcode }
      end
    end.compact
    puts "districts done"

    all = data.size
    district_streets = Hash[districts_map.map{|k,v| [k, []]}]
    streets = data.each_with_index.map do |i, index|
      print "#{index.to_f/all * 100}%\r"
      $stdout.flush
      district_id = districts_map[i[0..2].join('')]
      unless district_id
        not_found << i[0..3] + [3]
        next
      end
      district = district_streets[i[0..2].join('')]
      district << i[0..3].join('')
      { 'id' =>  district_id + district.size.to_s.rjust(3, '0'),
        'text' => i[3],
        'support_sf' => i[4] == '全境'
      }
    end.compact
    puts "streets done"

    File.open('db/areas.json', 'w') do |f|
      result = { province: provinces, 
                 cities: cities,
                 districts: districts,
                 streets: streets
               }
      f.write JSON.pretty_generate(result)
    end

    CSV.open('db/sf_not_found.csv', 'w') do |csv|
      not_found.each do |i|
        csv << i
      end
    end

  end

  private
  def city_should_fix
    arr = %w(海南省琼海市 海南省文昌市 海南省定安县 海南省屯昌县 海南省澄迈县 海南省临高县 海南省白沙黎族自治县 海南省昌江黎族自治县 海南省陵水黎族自治县 海南省保亭黎族苗族自治县 海南省琼中黎族苗族自治县 海南省五指山市 海南省万宁市 海南省东方市 海南省乐东黎族自治县 海南省三沙市 新疆维吾尔自治区石河子市 新疆维吾尔自治区五家渠市 新疆维吾尔自治区吐鲁番地区 新疆维吾尔自治区阿拉尔市 新疆维吾尔自治区图木舒克市 新疆维吾尔自治区伊犁哈萨克自治州 河南省济源市 湖北省神农架 湖北省仙桃市 湖北省潜江市 湖北省天门市)
  end

  def district_should_fix
    {
      "河北省保定市满城县"=>["130621", "072152"],
      "河北省保定市徐水县"=>["130625", "072550"],
      "黑龙江省大兴安岭地区新林区"=>["232703", "165023"],
      "吉林省长春市长春汽车产业开发区"=>["220198", "130062"],
      "吉林省长春市经济技术产业开发区"=>["220197", "130012"],
      "山东省济宁市市中区"=>["370811", "272000"],
      "江苏省无锡市崇安区"=>["320202", "214000"],
      "江苏省无锡市南长区"=>["320203", "214023"],
      "上海上海市闸北区"=>["310108", "200070"],
      "广西壮族自治区钦州市钦州港经济技术开发区"=>["450798", "535000"],
      "陕西省渭南市华县"=>["610503", "714100"],
      "湖南省常德市西湖区"=>["430798", "415000"]
    }
  end

end
