//Process reagents being input into the tray.
/obj/machinery/portable_atmospherics/hydroponics/proc/process_reagents()
	for(var/datum/reagent/A in reagents.reagent_list)
		A.on_plant_life(src)
	reagents.update_total()

/obj/machinery/portable_atmospherics/hydroponics/proc/add_nutrientlevel(var/amount, var/bloody = FALSE)
	if (!amount)
		return
	if(amount < 0)
		nutrientlevel = round(max(0, nutrientlevel + amount),0.01)
		if(nutrientlevel < 1)
			add_planthealth(-rand(1,3) * HYDRO_SPEED_MULTIPLIER)
			affect_growth(-1)
	else
		if(seed && !seed.hematophage && bloody)
			return
		if(seed && seed.hematophage && !bloody)
			return
		nutrientlevel = round(min(nutrientlevel + amount, NUTRIENTLEVEL_MAX),0.01)
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_nutrientlevel()
	return nutrientlevel

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_nutrientlevel()
	var/total = nutrientlevel
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_nutrition * R.volume
	return total

/obj/machinery/portable_atmospherics/hydroponics/proc/add_waterlevel(var/amount)
	if (!amount)
		return
	if(amount > 0)
		waterlevel = round(min(waterlevel + amount,WATERLEVEL_MAX),0.01)
		toxinlevel = round(max(toxinlevel - amount/2, 0),0.01)
	else
		//Remove or uptake water
		waterlevel = round(max(0, waterlevel + amount),0.01)
		if(waterlevel < 1)
			add_planthealth(-rand(1,3) * HYDRO_SPEED_MULTIPLIER)
			affect_growth(-1)
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_waterlevel()
	return waterlevel

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_waterlevel()
	var/total = waterlevel
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_watering * R.volume
	return total

/obj/machinery/portable_atmospherics/hydroponics/proc/add_pestlevel(var/amount)
	if (!amount)
		return
	if(amount > 0)
		pestlevel = round(min(pestlevel + amount,PESTLEVEL_MAX))
	else
		pestlevel = round(max(0, pestlevel + amount))
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_pestlevel()
	return pestlevel

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_pestlevel()
	var/total = pestlevel
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_pests * R.volume
	return total

/obj/machinery/portable_atmospherics/hydroponics/proc/add_weedlevel(var/amount)
	if (!amount)
		return
	if(amount > 0)
		weedlevel = round(min(weedlevel + amount,WEEDLEVEL_MAX))
	else
		weedlevel = round(max(0, weedlevel + amount))
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_weedlevel()
	return weedlevel

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_weedlevel()
	var/total = weedlevel
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_weeds * R.volume
	return total

/obj/machinery/portable_atmospherics/hydroponics/proc/add_toxinlevel(var/amount)
	if (!amount)
		return
	if(amount > 0)
		toxinlevel = round(min(toxinlevel + amount,TOXINLEVEL_MAX),0.01)
		waterlevel = round(max(waterlevel - amount/2, 0),0.01)
	else
		//Remove or uptake toxins
		toxinlevel = round(max(0, toxinlevel + amount),0.01)
		if(seed && !dead)
			if(toxinlevel < 1 && !(seed.toxin_affinity < 5))
				add_planthealth(-rand(1,3) * HYDRO_SPEED_MULTIPLIER)
				affect_growth(-1)
	//to update tray color
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_toxinlevel()
	return toxinlevel

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_toxinlevel()
	var/total = toxinlevel
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_toxins * R.volume
	return total

//plant_health is only modified here. This avoids the need for sanity checks every tick
/obj/machinery/portable_atmospherics/hydroponics/proc/add_planthealth(var/amount)
	if (!amount)
		return
	if(!seed)
		return
	if(dead)
		return
	if(amount > 0)
		plant_health = round(min(plant_health + amount, seed.endurance))
	else
		plant_health = round(max(0, plant_health + amount))
		if(get_planthealth() < 1)
			die()
	update_icon_after_process = 1

/obj/machinery/portable_atmospherics/hydroponics/proc/get_planthealth()
	return plant_health

/obj/machinery/portable_atmospherics/hydroponics/proc/get_full_planthealth()
	var/total = plant_health
	for(var/datum/reagent/R in reagents.reagent_list)
		total += R.plant_health * R.volume
	return total
