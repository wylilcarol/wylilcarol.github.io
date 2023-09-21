**ESM & 多种稳健估计量**                             2023.09.21

**1. Event Study（Dynamic TWFE）/ Parallel Trend Test 图示**
![](assets/assets/es3.png)
结果显示，以-1期为基期，处理前系数不稳定，处理后的0-2期系数为正，3期以后不稳定。

**Note：这个图示是用matrix保存各期系数画的，可以把-1期设置为0；下面画图用event_plot时没有一定保证-1期为0，用twoway画的时候使用矩阵保存系数可以保证-1期为0。**

<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
        use sample1.dta, clear

        *生成相对的时间值
        gen event = year - treatyear  
        replace event=0 if event==.
        tab event,m
        replace event = -5 if event <= -5  
        replace event = 5 if event >= 5
        tab event,m
        gen event_d=event+5
        
        egen countyid = group(county)
        egen cityid = group(city)
        
        *选择-1期作为基准组
        reghdfe lmwage ib4.event_d ${ind}, absorb(year cityid) vce(cluster cityid)
        
        *系数矩阵
        matrix coef = e(b) //系数
        matrix list coef
        matrix cov = e(V) //协方差矩阵
        matrix list cov 
        gen coef = .
        gen se = .
        forvalues i = 1(1)10 {
         replace coef = coef[1,`i'] if _n==`i'
         replace se = sqrt(cov[`i',`i']) if _n==`i'
        }
        gen lb=coef-invttail(e(df_r),0.025)*se //置信区间下界
        gen ub=coef+invttail(e(df_r),0.025)*se //置信区间上界
        keep coef se lb ub
        drop if coef == .
        
        input 
        0 0 0 0 
        end
        
        gen year = _n
        replace year = year - 6 if year < 5
        replace year = year - 5 if year >= 5 & year < 11
        replace year = -1 if year == 11
        sort year
        
        twoway (connect coef year,color(gs1) msize(small)) ///
        	(line lb year,lwidth(thin) lpattern(dash) lcolor(gs2)) ///
        	(line ub year,lwidth(thin) lpattern(dash) lcolor(gs2)), ///
        	yline(0,lwidth(vthin) lpattern(dash) lcolor(teal)) ///
        	xline(0,lwidth(vthin) lpattern(dash) lcolor(teal)) ///
        	ylabel(,labsize(*0.85) angle(0)) xlabel(-5(1)5,labsize(*0.75)) ///
        	ytitle("Coefficients") ///
        	xtitle("Event") ///
        	legend(off) ///图例
        	graphregion(color(white)) //白底
        
        graph export "$fig/assets/assets/es3.png", replace  as(png) width(800) height(600)
</details>                       

**2. 多种稳健估计量**  

**2.1 组别-时期ATT**
    
- *Callaway & Sant'Anna (2021)* **csdid**
![](assets/assets/cs.png)
结果显示，处理后正效应效果不大，有点看不出区别。
<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：把所有好的2*2DID组群-时间进行配对，那些always treated的组别就舍弃掉
    //作者提到可以采用三种方法进行估计：回归 (OR)、逆概率加权法 (IPW) 以及双重稳健法 (DR)
    //此处只介绍逆概率加权法估计量    
    use sample1.dta, clear
    replace treatyear=0 if treatyear==. //取值为 0 时表示，该样本为 "从未被处理" 的样本
    tab treatyear,m
    egen countyid = group(county)
    egen cityid = group(city)
    	
    csdid lmwage ${ind}, cluster(cityid)  time(year) ///
    	gvar(treatyear) method(reg) agg(event)  notyet
    	
    estat event, estore(cs) 
    
    event_plot cs, default_look ///
    	graph_opt(xtitle("Periods since the event") ///
    	ytitle("Average causal effect") xlabel(-5(1)6) ///
    	title("Callaway and Sant'Anna (2021)") name(CS, replace)) ///
    	stub_lag(Tp#) stub_lead(Tm#) together  
    	
    graph export "$fig/assets/assets/cs.png", replace 
</details>     

        
- *de Chaisemartin & D’ Haultfoeuille* 剔除动态效应的估计量 **did_multiplegt**
![](assets/assets/dCdH.png)
结果显示，这个图的趋势是最好的，处理前是负的，满足平行趋势，处理之后系数为正，且越来越大。
<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：将政策处理从无到有、从有到无两个正负方向的效果进行加权平均，而将两期的处理不变
    use sample1.dta, clear
    replace treatyear=0 if treatyear==. //取值为 0 时表示，该样本为 "从未被处理" 的样本
    tab treatyear,m
    egen countyid = group(county)
    egen cityid = group(city)
    
    did_multiplegt lmwage cityid year treat, ///
    	controls(${ind}) breps(50) cluster(cityid) ///
    	robust_dynamic dynamic(5) placebo(3)
    	
    matrix dcdh_b = e(estimates) 
    matrix dcdh_v = e(variances)
    
    event_plot e(estimates)#e(variances), default_look ///
    	graph_opt(xtitle("Periods since the event") ///
    	ytitle("Average causal effect") ///
    	title("de Chaisemartin and D'Haultfoeuille (2020)") ///
    	xlabel(-3(1)5) name(dCdH, replace)) ///
    	stub_lag(Effect_#) stub_lead(Placebo_#) together 
    
    graph export "$fig/assets/assets/dCdH.png", replace 

</details>
    
- Sun & Abraham（2021）**eventstudyinterect**
![](assets/assets/sa2.png)
结果显示，这个图也差不多是正效应，但是处理后政策效应不是很大。    
<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：使用后处理组作为控制组，允许使用简单的线性回归进行估计	
    use sample1.dta, clear
    gen event = year - treatyear //生成时间上的动态项
    replace event=0 if event==. //未收到政策影响用0填充，这允许在每个城市treat和event之间的交互，否则会出现NA
    gen never_treat = missing(treatyear) //缺失值则代表从未处理组
    egen cityid = group(city)
    
    //截尾处理
    
    replace event = -5 if event <= -5  
    replace event = 5 if event >= 5
    tab event,m
    
    //手动为处理组创建相对时间指标	
    forvalues t = -5(1)5 {
    	if `t' < -1 {
    		local tname = abs(`t')  //令tname为t的绝对值，免得生成变量名称为g_m-1
    		g g_m`tname' = event == `t'  //当event等于1，则生成g_m1 = 1
    	}
    		else if `t' >= 0 {
    		g g_`t' = event == `t'
    	}
    }	
    	
    eventstudyinteract lmwage g_*, cohort(treatyear) ///对于从未受政策处理过的单位，应将此分类变量设置为缺失
    	control_cohort(never_treat) covariates(${ind}) ///
    	absorb(year cityid) vce(cluster cityid) 
    	
    ********图2*********
    matrix T = r(table)
    mat list T
    g coef = 0 if event == -1
    g se = 0 if event == -1
    forvalues t = -5(1)5 {
    	if `t' < -1 {
    		local tname = abs(`t')
    		replace coef = T[1,colnumb(T,"g_m`tname'")] if event == `t'
    		replace se = T[2,colnumb(T,"g_m`tname'")] if event == `t'
    	}
    	else if `t' >= 0 {
    		replace coef =  T[1,colnumb(T,"g_`t'")] if event == `t'
    		replace se = T[2,colnumb(T,"g_`t'")] if event == `t'
    	}
    }
    //获取置信区间
    g ci_top = coef + 1.96*se
    g ci_bottom = coef - 1.96*se
    
    //根据event把重复了的剔除掉
    keep event coef se ci_*
    duplicates drop
    
    sort event
    keep if inrange(event, -5, 5)
    
    //创建连接的系数散点图，使用 rcap 中包含的 CI和水平和垂直方向为 0 的线
    summ ci_top
    local top_range = r(max)
    summ ci_bottom
    local bottom_range = r(min)
    
    twoway (connect coef event,color(gs1) msize(small)) ///
    	(line ci_top event,lwidth(thin) lpattern(dash) lcolor(gs2)) ///
    	(line ci_bottom event,lwidth(thin) lpattern(dash) lcolor(gs2)), ///
    	yline(0,lwidth(vthin) lpattern(dash) lcolor(teal)) ///
    	xline(0,lwidth(vthin) lpattern(dash) lcolor(teal)) ///
    	xtitle("Periods since the event") ///
    	ytitle("Average causal effect") xlabel(-5(1)5) ///
    	title("Sun and Abraham (2020)") name(sa2, replace) ///
    	legend(off) ///图例
    	graphregion(color(white)) //白底
    	
    graph export "$fig/assets/assets/sa2.png", replace 

</details>

**2.2 插补估计量**

- Borusyak、Jaravel and Spiess（2021 ）**did_imputation**
![](assets/assets/bjs.png)
和上面差不多。    
<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：基于 TWFE，通过估计组群固定效应、时间固定效应和处理组-控制组固定效应，可以得到更准确的估计量
    use sample1.dta, clear
    egen cityid = group(city)
    
    did_imputation lmwage cityid year treatyear, allhorizons pretrend(5) autosample
    estimates store bjs
    
    event_plot bjs, default_look ///
    	graph_opt(xtitle("Periods since the event") ///
    	xlabel(-5(1)7) name(bjs, replace) ///
    	ytitle("Average causal effect") ///
    	title("Borusyak et al. (2021) imputation estimator")) 
    	
    graph export "$fig/assets/assets/bjs.png", replace

</details>

**2.3 堆叠回归估计量**

- cengiz et al.（2019）**stackedev**
![](assets/assets/CDLZ.png)
和上面差不多。

<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：将数据集重建为相对事件时间的平衡面板，然后控制组群效应和时间固定效应，以得到处理效应的加权平均值
    use sample1.dta, clear
    gen event = year - treatyear //生成时间上的动态项
    replace event=0 if event==. //未收到政策影响用0填充，这允许在每个城市treat和event之间的交互，否则会出现NA
    gen never_treat = missing(treatyear) //生成从未受处理的虚拟变量
    egen cityid = group(city)
    
    //截尾处理
    replace event = -5 if event <= -5  
    replace event = 5 if event >= 5
    tab event,m
    
    tab treatyear, m
    forvalues l = 0/5 {
    	gen L`l'event = event ==`l'
    	replace L`l'event = 0 if never_treat==1
    }
    forvalues l = 1/5 {
    	gen F`l'event = event ==-`l'
    	replace F`l'event = 0 if never_treat==1
    }
    drop F1event
    
    stackedev lmwage F*event L*event, cohort(treatyear) ///
    	time(year) never_treat(never_treat) covariates($ind) ///
    	unit_fe(cityid) clust_unit(cityid) 
    
    event_plot e(b)#e(V), default_look ///
    	graph_opt(xtitle("Periods since the event")    ///
    	ytitle("Average causal effect") xlabel(-5(1)5) ///
    	title("Cengiz et al. (2019)") ///
    	name(CDLZ, replace)) stub_lag(L#event) stub_lead(F#event) together   
    
    graph export "$fig/assets/assets/CDLZ.png", replace

</details>

**2.4 两阶段DID 估计量，介于上述三类方法之间**
- Gardner （2021）**did2s**

![](assets/assets/DID2S.png)
结果显示，这个图拟合的也不错，处理之后的效应由负转为正，就是变化也不是很大。

<details>
<summary><mark><font color=darkred>点击查看详细code</font></mark></summary>
        
    //原理：在第一阶段识别组群处理效应和时期处理效应的异质性，在第二阶段时再将异质性处理效应剔除
    use sample1.dta, clear
    gen event = year - treatyear //生成时间上的动态项
    replace event=0 if event==. //未收到政策影响用0填充，这允许在每个城市treat和event之间的交互，否则会出现NA
    gen never_treat = missing(treatyear) //生成从未受处理的虚拟变量
    egen cityid = group(city)
    
    //截尾处理
    replace event = -5 if event <= -5  
    replace event = 5 if event >= 5
    tab event,m
    
    tab treatyear, m
    forvalues l = 0/5 {
    	gen L`l'event = event ==`l'
    	replace L`l'event = 0 if never_treat==1
    }
    forvalues l = 1/5 {
    	gen F`l'event = event ==-`l'
    	replace F`l'event = 0 if never_treat==1
    }
    
    did2s lmwage, first_stage(i.cityid i.year $ind) second_stage(F*event L*event) ///
    	treatment(treat) cluster(cityid) 
    
    event_plot, default_look ///
    	stub_lag(L#event) stub_lead(F#event) together          ///
    	graph_opt(xtitle("Periods since the event") ///
    	ytitle("Average causal effect") ///
    	xlabel(-5(1)5) title("Gardner (2021)") name(DID2S, replace)) 
    
    graph export "$fig/assets/assets/DID2S.png", replace

</details>