/obj/machinery/r_n_d/server
	name = "R&D Server"
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "server"
	var/datum/research/files
	health = 100
	var/list/id_with_upload = list()		//List of R&D consoles with upload to server access.
	var/list/id_with_download = list()	//List of R&D consoles with download from server access.
	var/id_with_upload_string = ""		//String versions for easy editing in map editor.
	var/id_with_download_string = ""
	var/server_id = 0
	var/heat_gen = 100
	var/heating_power = 40000
	var/delay = 10
	req_access = list(access_rd) //Only the R&D can change server settings.

/obj/machinery/r_n_d/server/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/rdserver,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/capacitor,
		/obj/item/weapon/stock_parts/capacitor
	)

	icon_state_open = icon_state // needs to be here to override what's done in the parent's New()

	RefreshParts()
	src.initialize(); //Agouri

/obj/machinery/r_n_d/server/Destroy()
	griefProtection()
	..()

/obj/machinery/r_n_d/server/RefreshParts()
	var/tot_rating = 0
	for(var/obj/item/weapon/stock_parts/SP in src)
		tot_rating += SP.rating
	heat_gen /= max(1, tot_rating)

/obj/machinery/r_n_d/server/initialize()
	if(!files)
		files = new /datum/research(src)
	var/list/temp_list
	if(!id_with_upload.len)
		temp_list = list()
		temp_list = splittext(id_with_upload_string, ";")
		for(var/N in temp_list)
			id_with_upload += text2num(N)
	if(!id_with_download.len)
		temp_list = list()
		temp_list = splittext(id_with_download_string, ";")
		for(var/N in temp_list)
			id_with_download += text2num(N)

/obj/machinery/r_n_d/server/process()
	var/datum/gas_mixture/environment = loc.return_readonly_air()
	switch(environment.temperature)
		if(0 to T0C)
			health = min(100, health + 1)
		if(T0C to (T20C + 20))
			health = clamp(health, 0, 100)
		if((T20C + 20) to INFINITY)
			health = max(0, health - 1)
	if(health <= 0)
		griefProtection() //I dont like putting this in process() but it's the best I can do without re-writing a chunk of rd servers.
		files.known_designs = list()
		var/changed=0
		for(var/ID in files.known_tech)
			var/datum/tech/T = files.known_tech[ID]
			if(prob(1))
				T.level = 0 // This never happens, so make it dramatic. T.level--
				message_admins("[src] lost [T.id] tech levels due to heat damage.")
				for(var/obj/machinery/computer/rdservercontrol/SC in machines)
					SC.screen = -1 //Display an alert
					SC.updateUsrDialog()
				changed=1
		if(changed)
			files.RefreshResearch()
	if(delay)
		delay--
	else
		produce_heat(heat_gen)
		delay = initial(delay)

/obj/machinery/r_n_d/server/emp_act(severity)
	griefProtection()
	..()


/obj/machinery/r_n_d/server/ex_act(severity)
	griefProtection()
	..()


/obj/machinery/r_n_d/server/blob_act()
	griefProtection()
	..()

/obj/machinery/r_n_d/server/update_icon()
	..()
	if(panel_open)
		overlays += "[initial(icon_state)]_panel"

//Backup files to centcomm to help admins recover data after greifer attacks
/obj/machinery/r_n_d/server/proc/griefProtection()
	for(var/obj/machinery/r_n_d/server/centcom/C in machines)
		for(var/ID in files.known_tech)
			var/datum/tech/T = files.known_tech[ID]
			C.files.AddTech2Known(T)
		for(var/datum/design/D in files.known_designs)
			C.files.AddDesign2Known(D)
		C.files.RefreshResearch()

/obj/machinery/r_n_d/server/proc/produce_heat(heat_amt)
	if(!(stat & (NOPOWER|BROKEN|FORCEDISABLE))) //Blatently stolen from space heater.
		var/turf/simulated/L = loc
		if(istype(L))
			var/datum/gas_mixture/env = L.return_air()
			if(env.temperature < (heat_amt + T0C))
				env.add_thermal_energy(min(heating_power, env.get_thermal_energy_change(1000)))

/obj/machinery/r_n_d/server/attack_hand(mob/user as mob)
	if (disabled)
		return
	if (shocked)
		shock(user,50)

/obj/machinery/r_n_d/server/centcom
	name = "Centcom Central R&D Database"
	server_id = -1

/obj/machinery/r_n_d/server/centcom/initialize()
	..()
	var/list/no_id_servers = list()
	var/list/server_ids = list()
	for(var/obj/machinery/r_n_d/server/S in machines)
		switch(S.server_id)
			if(-1)
				continue
			if(0)
				no_id_servers += S
			else
				server_ids += S.server_id

	for(var/obj/machinery/r_n_d/server/S in no_id_servers)
		var/num = 1
		while(!S.server_id)
			if(num in server_ids)
				num++
			else
				S.server_id = num
				server_ids += num
		no_id_servers -= S

/obj/machinery/r_n_d/server/centcom/process()
	return PROCESS_KILL	//don't need process()


/obj/machinery/computer/rdservercontrol
	name = "R&D Server Controller"
	icon_state = "rdcomp"
	var/screen = 0
	var/obj/machinery/r_n_d/server/temp_server
	var/list/servers = list()
	var/list/consoles = list()
	var/badmin = 0

	light_color = LIGHT_COLOR_PINK

/obj/machinery/computer/rdservercontrol/Topic(href, href_list)
	if(..())
		return

	add_fingerprint(usr)
	usr.set_machine(src)
	if(!src.allowed(usr) && !emagged)
		to_chat(usr, "<span class='warning'>You do not have the required access level</span>")
		return

	if(href_list["main"])
		screen = 0

	else if(href_list["access"] || href_list["data"] || href_list["transfer"])
		temp_server = null
		consoles = list()
		servers = list()
		for(var/obj/machinery/r_n_d/server/S in machines)
			if(S.server_id == text2num(href_list["access"]) || S.server_id == text2num(href_list["data"]) || S.server_id == text2num(href_list["transfer"]))
				temp_server = S
				break
		if(href_list["access"])
			screen = 1
			for(var/obj/machinery/computer/rdconsole/C in machines)
				if(C.sync)
					consoles += C
		else if(href_list["data"])
			screen = 2
		else if(href_list["transfer"])
			screen = 3
			for(var/obj/machinery/r_n_d/server/S in machines)
				if(S == src)
					continue
				servers += S

	else if(href_list["upload_toggle"])
		var/num = text2num(href_list["upload_toggle"])
		if(num in temp_server.id_with_upload)
			temp_server.id_with_upload -= num
		else
			temp_server.id_with_upload += num

	else if(href_list["download_toggle"])
		var/num = text2num(href_list["download_toggle"])
		if(num in temp_server.id_with_download)
			temp_server.id_with_download -= num
		else
			temp_server.id_with_download += num

	else if(href_list["reset_tech"])
		var/choice = alert("Technology Data Rest", "Are you sure you want to reset this technology to its default data? Data lost cannot be recovered.", "Continue", "Cancel")
		if(choice == "Continue")
			var/datum/tech/T = temp_server.files.GetKTechByID(href_list["reset_tech"])
			T.level = 1
		temp_server.files.RefreshResearch()

	else if(href_list["reset_design"])
		var/choice = alert("Design Data Deletion", "Are you sure you want to delete this design? If you still have the prerequisites for the design, it'll reset to its base reliability. Data lost cannot be recovered.", "Continue", "Cancel")
		if(choice == "Continue")
			for(var/datum/design/D in temp_server.files.known_designs)
				if(D.id == href_list["reset_design"])
					D.reliability_mod = 0
					temp_server.files.known_designs -= D
					break
		temp_server.files.RefreshResearch()

	updateUsrDialog()
	return

/obj/machinery/computer/rdservercontrol/attack_hand(mob/user as mob)
	if(stat & (BROKEN|NOPOWER|FORCEDISABLE))
		return
	user.set_machine(src)
	var/dat = ""

	switch(screen)
		if(-1)
			dat += "Alert! Technology data lost due to server heat damage.<BR><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"
		if(0) //Main Menu
			dat += "Connected Servers:<BR><BR>"

			for(var/obj/machinery/r_n_d/server/S in machines)
				if(istype(S, /obj/machinery/r_n_d/server/centcom) && !badmin)
					continue

				dat += {"[S.name] ||
					<A href='?src=\ref[src];access=[S.server_id]'> Access Rights</A> |
					<A href='?src=\ref[src];data=[S.server_id]'>Data Management</A>"}
				if(badmin)
					dat += " | <A href='?src=\ref[src];transfer=[S.server_id]'>Server-to-Server Transfer</A>"
				dat += "<BR>"

		if(1) //Access rights menu

			dat += {"[temp_server.name] Access Rights<BR><BR>
				Consoles with Upload Access<BR>"}
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];upload_toggle=[C.id]'>[console_turf.loc]" //FYI, these are all numeric ids, eventually.
				if(C.id in temp_server.id_with_upload)
					dat += " (Remove)</A><BR>"
				else
					dat += " (Add)</A><BR>"
			dat += "Consoles with Download Access<BR>"
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];download_toggle=[C.id]'>[console_turf.loc]"
				if(C.id in temp_server.id_with_download)
					dat += " (Remove)</A><BR>"
				else
					dat += " (Add)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(2) //Data Management menu

			dat += {"[temp_server.name] Data Management<BR><BR>
				Known Technologies<BR>"}
			for(var/ID in temp_server.files.known_tech)
				var/datum/tech/T = temp_server.files.known_tech[ID]
				dat += {"* [T.name]
					<A href='?src=\ref[src];reset_tech=[T.id]'>(Reset)</A><BR>"} //FYI, these are all strings
			dat += "Known Designs<BR>"
			for(var/datum/design/D in temp_server.files.known_designs)

				dat += {"* [D.name]
					<A href='?src=\ref[src];reset_design=[D.id]'>(Delete)</A><BR>"}
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(3) //Server Data Transfer

			dat += {"[temp_server.name] Server to Server Transfer<BR><BR>
				Send Data to what server?<BR>"}
			for(var/obj/machinery/r_n_d/server/S in servers)
				dat += "[S.name] <A href='?src=\ref[src];send_to=[S.server_id]'> (Transfer)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"
	user << browse("<TITLE>R&D Server Control</TITLE><HR>[dat]", "window=server_control;size=575x400")
	onclose(user, "server_control")
	return

/obj/machinery/computer/rdservercontrol/attackby(var/obj/item/weapon/D as obj, var/mob/user as mob)

	add_fingerprint(user)
	updateUsrDialog()
	if(D.is_screwdriver(user))
		D.playtoolsound(src, 50)
		if(do_after(user, src, 20))
			if (src.stat & BROKEN)
				to_chat(user, "<span class='notice'>The broken glass falls out.</span>")
				var/obj/structure/computerframe/A = new /obj/structure/computerframe( src.loc )
				new /obj/item/weapon/shard(loc)
				var/obj/item/weapon/circuitboard/rdservercontrol/M = new /obj/item/weapon/circuitboard/rdservercontrol( A )
				for (var/obj/C in src)
					C.forceMove(src.loc)
				A.circuit = M
				A.state = 3
				A.icon_state = "3"
				A.anchored = 1
				src.transfer_fingerprints_to(A)
				qdel(src)
			else
				to_chat(user, "<span class='notice'>You disconnect the monitor.</span>")
				var/obj/structure/computerframe/A = new /obj/structure/computerframe( src.loc )
				var/obj/item/weapon/circuitboard/rdservercontrol/M = new /obj/item/weapon/circuitboard/rdservercontrol( A )
				for (var/obj/C in src)
					C.forceMove(src.loc)
				A.circuit = M
				A.state = 4
				A.icon_state = "4"
				A.anchored = 1
				src.transfer_fingerprints_to(A)
				qdel(src)
	else
		return ..()

/obj/machinery/computer/rdservercontrol/emag_act(mob/user)
	if(!emagged)
		. = ..()
		emagged = 1
		to_chat(user, "<span class='notice'>You disable the security protocols</span>")

/obj/machinery/r_n_d/server/derelict
	name = "Derelict R&D Server"
	id_with_upload_string = "6"
	id_with_download_string = "6"
	server_id = 3

/obj/machinery/r_n_d/server/robotics
	name = "Robotics R&D Server"
	id_with_upload_string = "1;2"
	id_with_download_string = "1;2;3;4;5"
	server_id = 2

/obj/machinery/r_n_d/server/core
	name = "Core R&D Server"
	id_with_upload_string = "1"
	id_with_download_string = "1"
	server_id = 1
