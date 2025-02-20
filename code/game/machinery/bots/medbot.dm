//MEDBOT
//MEDBOT PATHFINDING
//MEDBOT ASSEMBLY
#define INJECTION_TIME 30

var/list/firstaid_exceptions = list(
	"antitoxfirstaid",
	"antitoxfirstaid2",
	"antitoxfirstaid3",
	"radfirstaid2",
	"radfirstaid3",
	"nanotrasen"
	)//these use a different mask since they don't have a "+" at the front

/obj/item/weapon/medbot_cube
	name = "advanced medibot cube"
	desc = "Compressed Nanotrasen Advanced Medibot, ready for deployment. Just unwrap the cube!"
	icon = 'icons/obj/aibots.dmi'
	icon_state = "medbotcube"

/obj/item/weapon/medbot_cube/attack_self(mob/user)
	user.visible_message("<span class='warning'>\The [src] suddenly expands into a fully functional medibot!</span>", \
	"<span class='warning'>You carefully unwrap \the [src] and it suddenly expands into a fully functional medibot!</span>")
	new /obj/machinery/bot/medbot/mysterious/nanotrasen(get_turf(src))
	qdel(src)


/obj/machinery/bot/medbot
	name = "Medibot"
	desc = "A little medical robot. He looks somewhat underwhelmed. It has a slot for pAIs."
	icon = 'icons/obj/aibots.dmi'
	icon_state = "medibot0"
	icon_initial = "medibot"
	density = 0
	anchored = 0
	health = 20
	maxHealth = 20
	req_access =list(access_medical)
	bot_flags = BOT_NOT_CHASING|BOT_CONTROL
	can_take_pai = TRUE
	var/stunned = 0 //It can be stunned by tasers. Delicate circuits.
	var/list/botcard_access = list(access_medical)
	var/obj/item/weapon/reagent_containers/glass/reagent_glass = null //Can be set to draw from this for reagents.
	var/skin = null //Set to "tox", "ointment" or "o2" for the other two firstaid kits.
	var/last_newpatient_speak = 0 //Don't spam the "HEY I'M COMING" messages
	var/currently_healing = 0
	var/injection_amount = 15 //How much reagent do we inject at a time?
	var/heal_threshold = 10 //Start healing when they have this much damage in a category
	var/use_beaker = 0 //Use reagents in beaker instead of default treatment agents.
	//Setting which reagents to use to treat what by default. By id.
	var/treatment_brute = BICARIDINE
	var/treatment_oxy = DEXALIN
	var/treatment_fire = KELOTANE
	var/treatment_tox = ANTI_TOXIN
	var/treatment_virus = SPACEACILLIN
	var/declare_treatment = 0 //When attempting to treat a patient, should it notify everyone wearing medhuds?
	var/shut_up = 0 //self explanatory :)
	var/declare_crit = 1 //If active, the bot will transmit a critical patient alert to MedHUD users.
	var/declare_cooldown = 0 //Prevents spam of critical patient alerts.
	var/pai_analyze_mode = FALSE //Used to switch between injecting people or analyzing them (for pAIs)
	var/reagent_id = null
	var/last_spoke = 0

	bot_type = MED_BOT
	commanding_radios = list(/obj/item/radio/integrated/signal/bot/medbot)

/obj/machinery/bot/medbot/splashable()
	return FALSE

/obj/machinery/bot/medbot/mysterious
	name = "Mysterious Medibot"
	desc = "International Medibot of mystery."
	skin = "bezerk"
	treatment_oxy = DEXALINP
	treatment_brute = BICARIDINE
	treatment_fire = KELOTANE
	treatment_tox = ANTI_TOXIN

/obj/machinery/bot/medbot/mysterious/nanotrasen
	name = "Nanotrasen Advanced Medibot"
	desc = "Not entirely a replacement for a real doctor."
	skin = "nanotrasen"

/obj/item/weapon/firstaid_arm_assembly
	name = "first aid/robot arm assembly"
	desc = "A first aid kit with a robot arm permanently grafted to it."
	icon = 'icons/obj/aibots.dmi'
	icon_state = "firstaid_arm"
	var/build_step = 0
	var/created_name = "Medibot" //To preserve the name if it's a unique medbot I guess
	var/skin = null
	var/image/skin_image = null
	w_class = W_CLASS_MEDIUM

/obj/item/weapon/firstaid_arm_assembly/New(turf/loc, var/new_skin)
	..()

	if (!skin)
		skin = new_skin ? new_skin : "firstaid"

	var/icon/I
	if (skin in firstaid_exceptions)
		I = new /icon('icons/obj/aibots.dmi', "mask_assembly_exception")
	else
		I = new /icon('icons/obj/aibots.dmi', "mask_assembly")

	I.Blend(new /icon('icons/obj/storage/storage.dmi', skin),ICON_MULTIPLY)

	/*
	var/icon/J = new /icon(icon,icon_state)
	J.Blend(I,ICON_OVERLAY)
	*/

	overlays += I

/obj/machinery/bot/medbot/New(turf/loc, var/new_skin)
	..()
	icon_state = "[icon_initial][on]"

	if (!skin)
		skin = new_skin ? new_skin : "firstaid"

	var/icon/I
	if (skin in firstaid_exceptions)
		I = new /icon('icons/obj/aibots.dmi', "mask_bot_exception")
	else
		I = new /icon('icons/obj/aibots.dmi', "mask_bot")

	I.Blend(new /icon('icons/obj/storage/storage.dmi', skin),ICON_MULTIPLY)
	I.Shift(EAST,5)
	I.Shift(SOUTH,5)

	/*
	var/icon/J = new /icon(icon,icon_state)
	J.Blend(I,ICON_OVERLAY)
	*/

	overlays += I

	botcard = new /obj/item/weapon/card/id(src)
	if(isnull(botcard_access) || (botcard_access.len < 1))
		var/datum/job/doctor/D = new/datum/job/doctor
		botcard.access = D.get_access()
	else
		botcard.access = botcard_access

/obj/machinery/bot/medbot/turn_on()
	. = ..()
	icon_state = "[icon_initial][on]"
	updateUsrDialog()

/obj/machinery/bot/medbot/turn_off()
	..()
	target = null
	old_targets = list()
	path = list()
	currently_healing = 0
	icon_state = "[icon_initial][on]"
	updateUsrDialog()

/obj/machinery/bot/medbot/attack_paw(mob/user)
	return attack_hand(user)

/obj/machinery/bot/medbot/attack_hand(mob/user)
	. = ..()
	if (.)
		return
	var/dat
	dat += "<TT><B>Automatic Medical Unit v1.1</B></TT><BR><BR>"
	dat += "Status: <A href='?src=\ref[src];power=1'>[on ? "On" : "Off"]</A><BR>"
	dat += "Maintenance panel panel is [open ? "opened" : "closed"]<BR>"
	dat += "Beaker: "
	if (reagent_glass)
		dat += "<A href='?src=\ref[src];eject=1'>Loaded \[[reagent_glass.reagents.total_volume]/[reagent_glass.reagents.maximum_volume]\]</a>"
	else
		dat += "None Loaded"
	dat += "<br>Behaviour controls are [locked ? "locked" : "unlocked"]<hr>"
	if(!locked || issilicon(user))
		dat += "<TT>Healing Threshold: "
		dat += "<a href='?src=\ref[src];adj_threshold=-10'>--</a> "
		dat += "<a href='?src=\ref[src];adj_threshold=-5'>-</a> "
		dat += "[heal_threshold] "
		dat += "<a href='?src=\ref[src];adj_threshold=5'>+</a> "
		dat += "<a href='?src=\ref[src];adj_threshold=10'>++</a>"
		dat += "</TT><br>"

		dat += "<TT>Injection Level: "
		dat += "<a href='?src=\ref[src];adj_inject=-5'>-</a> "
		dat += "[injection_amount] "
		dat += "<a href='?src=\ref[src];adj_inject=5'>+</a> "
		dat += "</TT><br>"

		dat += "Reagent Source: "
		dat += "<a href='?src=\ref[src];use_beaker=1'>[use_beaker ? "Loaded Beaker (When available)" : "Internal Synthesizer"]</a><br>"

		dat += "Treatment report is [declare_treatment ? "on" : "off"]. <a href='?src=\ref[src];declaretreatment=[1]'>Toggle</a><br>"

		dat += "The speaker switch is [shut_up ? "off" : "on"]. <a href='?src=\ref[src];togglevoice=[1]'>Toggle</a><br>"

		dat += "Critical Patient Alerts: <a href='?src=\ref[src];critalerts=1'>[declare_crit ? "Yes" : "No"]</a><br>"

	user << browse("<HEAD><TITLE>Medibot v1.0 controls</TITLE></HEAD>[dat]", "window=automed")
	onclose(user, "automed")
	return

/obj/machinery/bot/medbot/Topic(href, href_list)
	if(..())
		return
	usr.set_machine(src)
	add_fingerprint(usr)
	if ((href_list["power"]) && (allowed(usr)))
		if (on)
			turn_off()
		else
			turn_on()

	else if((href_list["adj_threshold"]) && (!locked || issilicon(usr)))
		var/adjust_num = text2num(href_list["adj_threshold"])
		heal_threshold += adjust_num
		if(heal_threshold < 5)
			heal_threshold = 5
		if(heal_threshold > 75)
			heal_threshold = 75

	else if((href_list["adj_inject"]) && (!locked || issilicon(usr)))
		var/adjust_num = text2num(href_list["adj_inject"])
		injection_amount += adjust_num
		if(injection_amount < 5)
			injection_amount = 5
		if(injection_amount > 15)
			injection_amount = 15

	else if((href_list["use_beaker"]) && (!locked || issilicon(usr)))
		use_beaker = !use_beaker

	else if (href_list["eject"] && (!isnull(reagent_glass)))
		if(!locked)
			reagent_glass.forceMove(get_turf(src))
			reagent_glass = null
		else
			to_chat(usr, "<span class='notice'>You cannot eject the beaker because the panel is locked.</span>")

	else if ((href_list["togglevoice"]) && (!locked || issilicon(usr)))
		shut_up = !shut_up

	else if ((href_list["declaretreatment"]) && (!locked || issilicon(usr)))
		declare_treatment = !declare_treatment

	else if ((href_list["critalerts"]) && (!locked || issilicon(usr)))
		declare_crit = !declare_crit

	updateUsrDialog()
	return

/obj/machinery/bot/medbot/attackby(obj/item/weapon/W, mob/user)
	if (istype(W, /obj/item/weapon/card/id)||istype(W, /obj/item/device/pda))
		if (allowed(user) && !open && !emagged)
			locked = !locked
			to_chat(user, "<span class='notice'>Controls are now [locked ? "locked." : "unlocked."]</span>")
			updateUsrDialog()
		else
			if(emagged)
				to_chat(user, "<span class='warning'>ERROR</span>")
			else if(open)
				to_chat(user, "<span class='warning'>Please close the access panel before locking it.</span>")
			else
				to_chat(user, "<span class='warning'>Access denied.</span>")

	else if (istype(W, /obj/item/weapon/reagent_containers/glass))
		if(locked)
			to_chat(user, "<span class='notice'>You cannot insert a beaker because the panel is locked.</span>")
			return
		if(!isnull(reagent_glass))
			to_chat(user, "<span class='notice'>There is already a beaker loaded.</span>")
			return
		if(W.w_class > W_CLASS_SMALL)
			to_chat(user, "<span class='warning'>\The [W] is too big to fit.</span>")
			return

		if(user.drop_item(W, src))
			reagent_glass = W
			to_chat(user, "<span class='notice'>You insert [W].</span>")
			investigation_log(I_CHEMS, "was loaded with \a [W] by [key_name(user)], containing [W.reagents.get_reagent_ids(1)]")
			updateUsrDialog()
			return

	else
		. = ..()
		if (. && isturf(loc))
			step_away(src,user)

/obj/machinery/bot/medbot/emag_act(mob/user)
	..()
	if(open && !locked)
		declare_crit = 0
		if(user)
			to_chat(user, "<span class='warning'>You short out [src]'s reagent synthesis circuits.</span>")
		for(var/mob/O in hearers(src, 7))
			O.show_message("<span class='danger'>[src] buzzes oddly!</span>", 1)
		flick("medibot_spark", src)
		playsound(src.loc, 'sound/medbot/Chemical_Detected.ogg', 35, channel = CHANNEL_MEDBOTS)
		target = null
		steps_per = 5 // Gotta go fast
		add_oldtarget(user.name)
		currently_healing = 0
		anchored = 0
		emagged = 2
		on = 1
		icon_state = "[icon_initial][on]"

/obj/machinery/bot/medbot/can_path()
	return !(stunned || currently_healing)

/obj/machinery/bot/medbot/process_bot()
	if(stunned)
		stunned--
		return

	if (can_abandon_target())
		target = null
		currently_healing = 0
		find_target()

	decay_oldtargets()

	if (get_dist(src, target) <= 1)
		if (summoned)
			summoned = FALSE
		path = list() // Kill our path
		if(!currently_healing)
			currently_healing = TRUE
			medicate_patient(target)

/obj/machinery/bot/medbot/proc/medicate_patient(mob/living/carbon/C)
	if(!on)
		return

	if(!istype(C))
		add_oldtarget(target.name)
		target = null
		return

	if(C.isDead())
		playsound(src.loc, 'sound/medbot/Flatline_custom.ogg', 35, channel = CHANNEL_MEDBOTS)
		visible_message("<b>[src]</b> points at [C.name]!")
		add_oldtarget(target.name)
		target = null
		return

	//Use whatever is inside the loaded beaker. If there is one.
	if((use_beaker) && (reagent_glass) && (reagent_glass.reagents.total_volume))
		reagent_id = "internal_beaker"

	if(emagged == 2) //Emagged! Time to poison everybody.
		reagent_id = TOXIN

	var/virus = 0
	for(var/ID in C.virus2)
		if (ID in virusDB)
			var/datum/data/record/v = virusDB[ID]
			if (v.fields["danger"] != "Safe")
				virus = 1

	if (!reagent_id && (virus))
		if(!C.reagents.has_reagent(treatment_virus))
			reagent_id = treatment_virus
			playsound(src.loc, 'sound/medbot/Biohazard_detected.ogg', 35, channel = CHANNEL_MEDBOTS)
			sleep(35)

	if (!reagent_id && (C.getBruteLoss() >= heal_threshold))
		if(!C.reagents.has_reagent(treatment_brute))
			reagent_id = treatment_brute
			if((C.getBruteLoss() <= 50) && (C.getBruteLoss() > 0) && (shut_up == 0))
				playsound(src.loc, 'sound/medbot/Minor_lacerations.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Minor lacerations detected!")
				sleep(35)
			if(C.getBruteLoss() > 50 && (shut_up == 0))
				playsound(src.loc, 'sound/medbot/Major_lacerations.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Major lacerations detected!")
				sleep(35)

	if (!reagent_id && (C.getOxyLoss() >= heal_threshold))
		if(!C.reagents.has_reagent(treatment_oxy))
			reagent_id = treatment_oxy
			if(shut_up == 0)
				playsound(src.loc, 'sound/medbot/Blood_loss.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Blood loss detected!")
				sleep(25)

	if (!reagent_id && (C.getFireLoss() >= heal_threshold))
		if(!C.reagents.has_reagent(treatment_fire))
			reagent_id = treatment_fire
			if(shut_up == 0)
				playsound(src.loc, 'sound/medbot/Heat_damage.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Warning! Extreme heat damage detected!")
				sleep(45)


	if (!reagent_id && (C.getToxLoss() >= heal_threshold))
		if(!C.reagents.has_reagent(treatment_tox))
			reagent_id = treatment_tox
			if(shut_up == 0)
				playsound(src.loc, 'sound/medbot/Blood_toxins.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Warning! Blood toxin levels detected!")
				sleep(45)
				playsound(src.loc, 'sound/medbot/Antitoxin_shot.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Antitoxin administered!")
				sleep(25)


	if(!reagent_id) //If they don't need any of that they're probably cured!
		add_oldtarget(target.name)
		target = null
		currently_healing = 0
		return
	else
		icon_state = "[icon_initial]s"
		visible_message("<span class='danger'>[src] is trying to inject [target]!</span>")

		if(integratedpai)
			if(do_after(integratedpai.pai, src, INJECTION_TIME))
				inject_patient()
		else
			spawn(INJECTION_TIME)
				inject_patient()

/obj/machinery/bot/medbot/proc/inject_patient()

	var/succesful_inject = 0
	if ((get_dist(src, target) <= 1) && (on))
		if((reagent_id == "internal_beaker") && (reagent_glass) && (reagent_glass.reagents.total_volume))
			reagent_glass.reagents.trans_to(target,injection_amount) //Inject from beaker instead.
			reagent_glass.reagents.reaction(target, 2)
			succesful_inject = 1
		else
			if(!target.reagents.has_reagent(reagent_id) && !emagged) //Somebody got there first
				target.reagents.add_reagent(reagent_id,injection_amount)
				succesful_inject = 1
	if(succesful_inject)
		visible_message("<span class='danger'>[src] injects [target] with the syringe!</span>")

	icon_state = "[icon_initial][on]"
	currently_healing = 0
	reagent_id = null

	return

/obj/machinery/bot/medbot/proc/speak(var/message)
	if((!on) || (!message))
		return
	visible_message("<b>[src]</b> beeps, \"[message]\"",\
		drugged_message="<b>[src]</b> beeps, \"[pick("FEED ME HUMANS","LET THE BLOOD FLOW","BLOOD FOR THE BLOOD GOD","I SPREAD DEATH AND DESTRUCTION","EXTERMINATE","I HATE YOU!","SURRENDER TO YOUR MACHINE OVERLORDS","FEED ME SHITTERS")]\"")
	return

/obj/machinery/bot/medbot/bullet_act(var/obj/item/projectile/Proj)
	if(Proj.flag == "taser")
		stunned = min(stunned+10,20)
	return ..()

/obj/machinery/bot/medbot/explode()
	on = 0
	visible_message("<span class='danger'>[src] blows apart!</span>", 1)
	playsound(src.loc, 'sound/medbot/Flatline_custom.ogg', 35, channel = CHANNEL_MEDBOTS)
	var/turf/Tsec = get_turf(src)

	var/obj/item/weapon/storage/firstaid/medkit = new (Tsec)
	medkit.icon_state = skin

	new /obj/item/device/assembly/prox_sensor(Tsec)
	new /obj/item/device/healthanalyzer(Tsec)

	if(reagent_glass)
		reagent_glass.forceMove(Tsec)
		reagent_glass = null

	if (prob(50))
		new /obj/item/robot_parts/l_arm(Tsec)

	spark(src)
	eject_integratedpai_if_present()
	qdel(src)
	return

/obj/machinery/bot/medbot/target_selection()
	look_for_target = TRUE
	for (var/mob/living/carbon/C in view(target_chasing_distance,src)) //Time to find a patient!
		if ((C.isDead()) || !istype(C, /mob/living/carbon/human))
			continue

		if (C.name in old_targets)
			continue

		if(assess_patient(C))
			target = C
			if((last_newpatient_speak + 100 < world.time) &&  (shut_up == 0)) //Don't spam these messages!
				playsound(src.loc, 'sound/medbot/Administering_medical.ogg', 35, channel = CHANNEL_MEDBOTS)
				say("Administering medical attention!")
				last_newpatient_speak = world.time
				if(declare_treatment)
					var/area/location = get_area(src)
					broadcast_medical_hud_message("[name] is treating <b>[C]</b> in <b>[location]</b>", src)
			visible_message("<b>[src]</b> points at [C.name]!")
			process_path() // Let's waste no time
			look_for_target = FALSE
			break
	look_for_target = FALSE

/obj/machinery/bot/medbot/proc/assess_patient(mob/living/carbon/C)
	//Time to see if they need medical help!
	if(C.isDead())
		return 0 //welp too late for them!

	if(C.mind && C.mind.suiciding)
		return 0 //Kevorkian school of robotic medical assistants.

	if(emagged == 2) //Everyone needs our medicine. (Our medicine is toxins)
		return 1

	if(declare_crit && C.health <= 0) //Critical condition! Call for help!
		declare()

	//If they're injured, we're using a beaker, and don't have one of our WONDERCHEMS.
	if((reagent_glass) && (use_beaker) && ((C.getBruteLoss() >= heal_threshold) || (C.getToxLoss() >= heal_threshold) || (C.getToxLoss() >= heal_threshold) || (C.getOxyLoss() >= (heal_threshold + 15))))
		for(var/datum/reagent/R in reagent_glass.reagents.reagent_list)
			if(!C.reagents.has_reagent(R))
				return 1
			continue

	//They're injured enough for it!
	if((C.getBruteLoss() >= heal_threshold) && (!C.reagents.has_reagent(treatment_brute)))
		return 1 //If they're already medicated don't bother!

	if((C.getOxyLoss() >= (15 + heal_threshold)) && (!C.reagents.has_reagent(treatment_oxy)))
		return 1

	if((C.getFireLoss() >= heal_threshold) && (!C.reagents.has_reagent(treatment_fire)))
		return 1

	if((C.getToxLoss() >= heal_threshold) && (!C.reagents.has_reagent(treatment_tox)))
		return 1

	for(var/ID in C.virus2)
		if (ID in virusDB)
			var/datum/data/record/v = virusDB[ID]
			if ((v.fields["danger"] != "Safe") && (!C.reagents.has_reagent(treatment_virus)))
				return 1

	return 0

/obj/machinery/bot/medbot/return_status()
	if (currently_healing)
		return "Healing"
	if (auto_patrol)
		return "Patrolling"
	return ..()

/*
 *	Medbot Assembly -- Can be made out of all three medkits.
 */

/obj/item/weapon/storage/firstaid/attackby(var/obj/item/robot_parts/S, mob/user as mob)

	if ((!istype(S, /obj/item/robot_parts/l_arm)) && (!istype(S, /obj/item/robot_parts/r_arm)))
		. = ..()
		return

	//Making a medibot!
	if(contents.len >= 1)
		to_chat(user, "<span class='notice'>You need to empty [src] out first.</span>")
		return

	user.create_in_hands(src, new /obj/item/weapon/firstaid_arm_assembly(get_turf(src),icon_state), S, msg = "<span class='notice'>You add the robot arm to the first aid kit.</span>")

/obj/item/weapon/firstaid_arm_assembly/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(istype(W, /obj/item/weapon/pen))
		var/t = copytext(stripped_input(user, "Enter new robot name", name, created_name),1,MAX_NAME_LEN)
		if (!t)
			return
		if (!in_range(src, usr) && loc != usr)
			return
		created_name = t
	else
		switch(build_step)
			if(0)
				if(istype(W, /obj/item/device/healthanalyzer))
					if(user.drop_item(W))
						qdel(W)
						build_step++
						to_chat(user, "<span class='notice'>You add the health sensor to [src].</span>")
						name = "First aid/robot arm/health analyzer assembly"
						overlays += image('icons/obj/aibots.dmi', "na_scanner")

			if(1)
				if(isprox(W))
					if(user.drop_item(W))
						qdel(W)
						build_step++
						to_chat(user, "<span class='notice'>You complete the Medibot! Beep boop.</span>")
						playsound(src.loc, 'sound/medbot/Automedic_on.ogg', 35, channel = CHANNEL_MEDBOTS)
						var/turf/T = get_turf(src)
						var/obj/machinery/bot/medbot/S = new /obj/machinery/bot/medbot(T,skin)
						S.skin = skin
						S.name = created_name
						user.drop_from_inventory(src)
						qdel(src)


/obj/machinery/bot/medbot/declare()
	if(declare_cooldown)
		return
	var/area/location = get_area(src)
	declare_message = "<span class='info'>[bicon(src)] Medical emergency! A patient is in critical condition at [location]!</span>"
	visible_message("<span class='info'>[bicon(src)] Medical emergency! A patient is in critical condition at [location]!</span>")
	..()
	declare_cooldown = 1
	spawn(100) //Ten seconds
		declare_cooldown = 0

/*
 *	pAI SHIT, it uses the pAI framework in objs.dm. Check that code for further information
*/

/obj/machinery/bot/medbot/install_pai(obj/item/device/paicard/P)
	..()
	overlays += image('icons/obj/aibots.dmi', "medibot_pai_overlay")

/obj/machinery/bot/medbot/eject_integratedpai_if_present()
	if(..())
		overlays -= image('icons/obj/aibots.dmi', "medibot_pai_overlay")

/obj/machinery/bot/medbot/on_integrated_pai_click(mob/living/silicon/pai/user, mob/living/carbon/A)
	if(!Adjacent(A))
		return

	target = A //Needed because medicate_patient doesn't set up one.

	if(pai_analyze_mode)
		if(istype(A, /mob/living/carbon))
			healthanalyze(A, user, 1)
	else
		medicate_patient(A)

/obj/machinery/bot/medbot/dropkey_integrated_pai(mob/living/silicon/pai/user)	//called when integrated pAI uses the drop hotkey
	declare()

/obj/machinery/bot/medbot/swapkey_integrated_pai(mob/living/silicon/pai/user)	//called when integrated pAI uses the swap_hand() hotkey
	pai_analyze_mode ? to_chat(user, "<span class='info'>You switch to inject mode.</span>") : to_chat(user, "<span class='info'>You switch to analyze mode.</span>")
	pai_analyze_mode = !pai_analyze_mode

/obj/machinery/bot/medbot/state_controls_pai(obj/item/device/paicard/P)
	if(..())
		to_chat(P.pai, "<span class='info'><b>Welcome to your new body. Remember: you're a pAI inside a medbot, not a medbot.</b></span>")
		to_chat(P.pai, "<span class='info'>It is highly recommended to download the Medical Supplement from the pAI software interface as it gives you MedHUD.</span>")
		to_chat(P.pai, "<span class='info'>Your controls are:</span>")
		to_chat(P.pai, "<span class='info'>- (Q) Drop hotkey: You state there's a patient in critical condition</span>")
		to_chat(P.pai, "<span class='info'>- (X) Swap hands:  You switch to inject or analyze mode.</span>")
		to_chat(P.pai, "<span class='info'>- Click on somebody: Depending on your mode, you inject or analyze a person.</span>")
		to_chat(P.pai, "<span class='info'>What you inject depends on the medbot's configuration. You can't modify it</span>")
		to_chat(P.pai, "<span class='info'>If you want to exit the medbot, somebody has to right-click you and press 'Remove pAI'.</span>")
