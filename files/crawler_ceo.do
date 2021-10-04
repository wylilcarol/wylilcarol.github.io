******************************************************
*	Title : Stata爬虫案例
*	Task  : 新浪财经上市公司高管任职数据爬取  
*	Date  : 2021.09.11                     
******************************************************

* 设定工作路径
clear all
global path "D:\Dropbox\Crawler"
global data "$path\data"
cd "$data"

*======================
*  一、单个网页抓取 
*======================

*获取网页源代码
copy "http://vip.stock.finance.sina.com.cn/corp/go.php/vCI_CorpManager/stockid/600900.phtml" temp.txt, replace  

*导入文本
infix strL v 1-100000 using temp.txt, clear

*乱码处理    
replace v = ustrfrom(v, "gb18030", 1)      

*提取信息
keep if index(v, "</div></td>")
drop if index(v, "</strong>") | v == "</div></td>"

*构建高管单个页面的网址 
gen url = "http://vip.stock.finance.sina.com.cn/" + ustrregexs(1) if ustrregexm(v, `"href="(.*?)""')  

*保留需要的数据
replace v = ustrregexra(v, "<.*?>", "")     

gen v1 = v[_n + 1]
gen v2 = v[_n + 2]
gen v3 = v[_n + 3]
keep if mod(_n, 4) == 1
rename v* (姓名 职务 起始日期 终止日期)
gen stkcd = 600900    

compress
save "600900.dta", replace

*=======================
*  二、多家上市公司抓取
*=======================

cnstock SHA                   //上海上市的a股公司的股票代码和股票名称数据
sample 10, count              //选任意10家公司
levelsof stkcd, local(stkcd)    

*遍历每家上市公司的网址，重复上述操作
foreach stk in `stkcd' {
	local stk: disp %06.0f `stk'
	cap copy "http://vip.stock.finance.sina.com.cn/corp/go.php/vCI_CorpManager/stockid/`stk'.phtml" temp.txt, replace
	infix strL v 1-100000 using temp.txt, clear
	replace v = ustrfrom(v, "gb18030", 1)
	keep if index(v, "</div></td>")
	drop if index(v, "</strong>") | v == "</div></td>"
	gen url = "http://vip.stock.finance.sina.com.cn/" + ustrregexs(1) if ustrregexm(v, `"href="(.*?)""')
	replace v = ustrregexra(v, "<.*?>", "")
	gen v1 = v[_n + 1]
	gen v2 = v[_n + 2]
	gen v3 = v[_n + 3]
	keep if mod(_n, 4) == 1
	rename v* (姓名 职务 起始日期 终止日期)
	gen stkcd = `stk'
	compress
	save "`stk'.dta", replace
}

clear
local files: dir "." file "6*.dta"
foreach file in `files' {
	append using "`file'"
	save "allstk.dta", replace
}
  
*==============================
*  三、高管简历单个网页抓取
*==============================

copy "http://vip.stock.finance.sina.com.cn/corp/view/vCI_CorpManagerInfo.php?stockid=600900&Pcode=30028965&Name=%B3%C2%B9%FA%C7%EC" temp.txt, replace
infix strL v 1-100000 using temp.txt, clear
replace v = ustrfrom(v, "gb18030", 1)
keep if index(v, `"<td><div align="center">"') | index(v, `"<td colspan="4" class="graybgH">"')
keep in 1/6
replace v = ustrregexra(v, "<.*?>", "")
sxpose, clear 
rename _all (姓名 性别 出生日期 学历 国籍 简历)
save "1.dta", replace
  
*============================
*  四、所有高管简历
*============================

use "allstk.dta", clear
keep if stkcd==stkcd[1]     //选1家公司
save "allstk1.dta", replace 
    
levelsof url, local(url)
local i = 1 
foreach u in `url' {
	cap copy `"`u'"' "temp.txt", replace
	*dis `"`u'"'
	infix strL v 1-100000 using "temp.txt", clear
	replace v = ustrfrom(v, "gb18030", 1)
	keep if index(v, `"<td><div align="center">"') | index(v, `"<td colspan="4" class="graybgH">"')
	keep in 1/6
	replace v = ustrregexra(v, "<.*?>", "")
	sxpose, clear
	rename _all (姓名 性别 出生日期 学历 国籍 简历)
	save "p`i'.dta", replace
	local i = `i' + 1
}

clear
local files: dir "." file "p*.dta"
foreach file in `files' {
	append using "`file'"
	save "allceo.dta", replace
}

merge 1:m 姓名 using "allstk1.dta"
drop _m
replace 学历="" if 学历=="&nbsp;"
save ceo.dta, replace 
