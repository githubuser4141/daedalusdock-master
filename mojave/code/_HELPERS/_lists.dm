//MOJAVE MODULE OUTDOOR_EFFECTS -- BEGIN
//Scales a range (i.e 1,100) and picks an item from the list based on your passed value
//i.e in a list with length 4, a 25 in the 1-100 range will give you the 2nd item
//This assumes your ranges start with 1, I am not good at math and can't do linear scaling
/proc/scale_range_pick(min,max,value,list/L)
	if(!length(L))
		return null
	var/index = 1 + (value * (length(L) - 1)) / (max - min)
	return L[index]
//MOJAVE MODULE OUTDOOR_EFFECTS -- END
