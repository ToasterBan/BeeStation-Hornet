#define SENSORS_OFF 0
#define SENSORS_BINARY 1
#define SENSORS_VITALS 2
#define SENSORS_TRACKING 3
#define SENSOR_CHANGE_DELAY 1.5 SECONDS

/obj/item/clothing
	name = "clothing"
	resistance_flags = FLAMMABLE
	max_integrity = 200
	integrity_failure = 0.4
	var/damaged_clothes = 0 //similar to machine's BROKEN stat and structure's broken var
	var/flash_protect = 0		//What level of bright light protection item has. 1 = Flashers, Flashes, & Flashbangs | 2 = Welding | -1 = OH GOD WELDING BURNT OUT MY RETINAS
	var/bang_protect = 0		//what level of sound protection the item has. 1 is the level of a normal bowman.
	var/tint = 0				//Sets the item's level of visual impairment tint, normally set to the same as flash_protect
	var/up = 0					//but separated to allow items to protect but not impair vision, like space helmets
	var/visor_flags = 0			//flags that are added/removed when an item is adjusted up/down
	var/visor_flags_inv = 0		//same as visor_flags, but for flags_inv
	var/visor_flags_cover = 0	//same as above, but for flags_cover
//what to toggle when toggled with weldingvisortoggle()
	var/visor_vars_to_toggle = VISOR_FLASHPROTECT | VISOR_TINT | VISOR_VISIONFLAGS | VISOR_DARKNESSVIEW | VISOR_INVISVIEW
	lefthand_file = 'icons/mob/inhands/clothing_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/clothing_righthand.dmi'
	var/alt_desc = null
	var/toggle_message = null
	var/alt_toggle_message = null
	var/active_sound = null
	var/cooldown = 0
	var/envirosealed = FALSE //is it safe for plasmamen

	var/blocks_shove_knockdown = FALSE //Whether wearing the clothing item blocks the ability for shove to knock down.

	var/clothing_flags = NONE

	var/can_be_bloody = TRUE

	//Var modification - PLEASE be careful with this I know who you are and where you live
	var/list/user_vars_to_edit //VARNAME = VARVALUE eg: "name" = "butts"
	var/list/user_vars_remembered //Auto built by the above + dropped() + equipped()

	/// Trait modification, lazylist of traits to add/take away, on equipment/drop in the correct slot

	var/pocket_storage_component_path

	//These allow head/mask items to dynamically alter the user's hair
	// and facial hair, checking hair_extensions.dmi and facialhair_extensions.dmi
	// for a state matching hair_state+dynamic_hair_suffix
	// THESE OVERRIDE THE HIDEHAIR FLAGS
	var/dynamic_hair_suffix = ""//head > mask for head hair
	var/dynamic_fhair_suffix = ""//mask > head for facial hair

	var/high_pressure_multiplier = 1
	var/static/list/high_pressure_multiplier_types = list(MELEE, BULLET, LASER, ENERGY, BOMB)

/obj/item/clothing/Initialize(mapload)
	if(CHECK_BITFIELD(clothing_flags, VOICEBOX_TOGGLABLE))
		actions_types += /datum/action/item_action/toggle_voice_box
	. = ..()
	if(ispath(pocket_storage_component_path))
		LoadComponent(pocket_storage_component_path)
	if(can_be_bloody && ((body_parts_covered & FEET) || (flags_inv & HIDESHOES)))
		LoadComponent(/datum/component/bloodysoles)

/obj/item/clothing/MouseDrop(atom/over_object)
	. = ..()
	var/mob/M = usr

	if(ismecha(M.loc)) // stops inventory actions in a mech
		return

	if(!M.incapacitated() && loc == M && istype(over_object, /atom/movable/screen/inventory/hand))
		var/atom/movable/screen/inventory/hand/H = over_object
		if(M.putItemFromInventoryInHandIfPossible(src, H.held_index))
			add_fingerprint(usr)

/obj/item/food/clothing // fuck you
	name = "temporary moth clothing snack item"
	desc = "If you're reading this it means I messed up. This is related to moths eating clothes and I didn't know a better way to do it than making a new food object." // die
	food_reagents = list(/datum/reagent/consumable/nutriment = 1)
	tastes = list("dust" = 1, "lint" = 1)
	foodtypes = CLOTH

/obj/item/clothing/attack(mob/M, mob/user, def_zone)
	if(user.a_intent != INTENT_HARM && (ismoth(M) || ispsyphoza(M)) && !(clothing_flags & NOTCONSUMABLE) && !(resistance_flags & INDESTRUCTIBLE) && (armor.getRating(MELEE) == 0))
		var/obj/item/food/clothing/clothing_as_food = new // I shall send you to hell in the next PR
		clothing_as_food.name = name
		if(clothing_as_food.attack(M, user, def_zone))
			take_damage(15, sound_effect=FALSE)
		qdel(clothing_as_food)
	else
		return ..()

/obj/item/clothing/attackby(obj/item/W, mob/user, params)
	if(damaged_clothes && istype(W, /obj/item/stack/sheet/cotton/cloth))
		var/obj/item/stack/sheet/cotton/cloth/C = W
		C.use(1)
		update_clothes_damaged_state(FALSE)
		obj_integrity = max_integrity
		to_chat(user, "<span class='notice'>You fix the damage on [src] with [C].</span>")
		return 1
	return ..()

/obj/item/clothing/Destroy()
	user_vars_remembered = null //Oh god somebody put REFERENCES in here? not to worry, we'll clean it up
	return ..()

/obj/item/clothing/dropped(mob/user)
	..()
	if(!istype(user))
		return
	if(LAZYLEN(user_vars_remembered))
		for(var/variable in user_vars_remembered)
			if(variable in user.vars)
				if(user.vars[variable] == user_vars_to_edit[variable]) //Is it still what we set it to? (if not we best not change it)
					user.vars[variable] = user_vars_remembered[variable]
		user_vars_remembered = initial(user_vars_remembered) // Effectively this sets it to null.

/obj/item/clothing/equipped(mob/user, slot)
	. = ..()
	if (!istype(user))
		return
	if(slot_flags & slot) //Was equipped to a valid slot for this item?
		if (LAZYLEN(user_vars_to_edit))
			for(var/variable in user_vars_to_edit)
				if(variable in user.vars)
					LAZYSET(user_vars_remembered, variable, user.vars[variable])
					user.vv_edit_var(variable, user_vars_to_edit[variable])

/obj/item/clothing/examine(mob/user)
	. = ..()
	switch (max_heat_protection_temperature)
		if (400 to 1000)
			. += "[src] offers the wearer limited protection from fire."
		if (1001 to 1600)
			. += "[src] offers the wearer some protection from fire."
		if (1601 to 35000)
			. += "[src] offers the wearer robust protection from fire."
	if(damaged_clothes)
		. += "<span class='warning'>It looks damaged!</span>"

	/* Bodypart wounds-related shit for when we eventually port https://github.com/tgstation/tgstation/pull/50558
	*
	for(var/zone in damage_by_parts)
		var/pct_damage_part = damage_by_parts[zone] / limb_integrity * 100
		var/zone_name = parse_zone(zone)
		switch(pct_damage_part)
			if(100 to INFINITY)
				. += span_warning("<b>The [zone_name] is useless and requires mending!</b>")
			if(60 to 99)
				. += span_warning("The [zone_name] is heavily shredded!")
			if(30 to 59)
				. += span_danger("The [zone_name] is partially shredded.")
	*/

	var/datum/component/storage/pockets = GetComponent(/datum/component/storage)
	if(pockets)
		var/list/how_cool_are_your_threads = list("<span class='notice'>")
		if(pockets.attack_hand_interact)
			how_cool_are_your_threads += "[src]'s storage opens when clicked.\n"
		else
			how_cool_are_your_threads += "[src]'s storage opens when dragged to yourself.\n"
		if (pockets.can_hold?.len) // If pocket type can hold anything, vs only specific items
			how_cool_are_your_threads += "[src] can store [pockets.max_items] item\s.\n"
		else
			how_cool_are_your_threads += "[src] can store [pockets.max_items] item\s that are [weight_class_to_text(pockets.max_w_class)] or smaller.\n"
		if(pockets.quickdraw)
			how_cool_are_your_threads += "You can quickly remove an item from [src] using Alt-Click.\n"
		if(pockets.silent)
			how_cool_are_your_threads += "Adding or removing items from [src] makes no noise.\n"
		how_cool_are_your_threads += "</span>"
		. += how_cool_are_your_threads.Join()

	if(armor.bio || armor.bomb || armor.bullet || armor.energy || armor.laser || armor.melee || armor.fire || armor.acid || armor.stamina || (flags_cover & HEADCOVERSMOUTH))
		. += "<span class='notice'>It has a <a href='?src=[REF(src)];list_armor=1'>tag</a> listing its protection classes.</span>"

/obj/item/clothing/Topic(href, href_list)
	. = ..()

	if(href_list["list_armor"])
		var/obj/item/clothing/compare_to = null
		for (var/flag in bitfield_to_list(slot_flags))
			var/thing = usr.get_item_by_slot(flag)
			if (istype(thing, /obj/item/clothing))
				compare_to = thing
				break
		var/list/readout = list("<span class='notice'><u><b>PROTECTION CLASSES</u></b>")
		if(armor.bio || armor.bomb || armor.bullet || armor.energy || armor.laser || armor.magic || armor.melee || armor.rad || armor.stamina)
			readout += "<br /><b>ARMOR (I-X)</b>"
			if(armor.bio || compare_to?.armor?.bio)
				readout += "<br />TOXIN [armor_to_protection_class(armor.bio, compare_to?.armor?.bio)]"
			if(armor.bomb || compare_to?.armor?.bomb)
				readout += "<br />EXPLOSIVE [armor_to_protection_class(armor.bomb, compare_to?.armor?.bomb)]"
			if(armor.bullet || compare_to?.armor?.bullet)
				readout += "<br />BULLET [armor_to_protection_class(armor.bullet, compare_to?.armor?.bullet)]"
			if(armor.energy || compare_to?.armor?.energy)
				readout += "<br />ENERGY [armor_to_protection_class(armor.energy, compare_to?.armor?.energy)]"
			if(armor.laser || compare_to?.armor?.laser)
				readout += "<br />LASER [armor_to_protection_class(armor.laser, compare_to?.armor?.laser)]"
			if(armor.magic || compare_to?.armor?.magic)
				readout += "<br />MAGIC [armor_to_protection_class(armor.magic, compare_to?.armor?.magic)]"
			if(armor.melee || compare_to?.armor?.melee)
				readout += "<br />MELEE [armor_to_protection_class(armor.melee, compare_to?.armor?.melee)]"
			if(armor.rad || compare_to?.armor?.rad)
				readout += "<br />RADIATION [armor_to_protection_class(armor.rad, compare_to?.armor?.rad)]"
			if(armor.stamina || compare_to?.armor?.stamina)
				readout += "<br />STAMINA [armor_to_protection_class(armor.stamina, compare_to?.armor?.stamina)]"
		if(armor.fire || armor.acid)
			readout += "<br /><b>DURABILITY (I-X)</b>"
			if(armor.fire || compare_to?.armor?.fire)
				readout += "<br />FIRE [armor_to_protection_class(armor.fire, compare_to?.armor?.fire)]"
			if(armor.acid || compare_to?.armor?.acid)
				readout += "<br />ACID [armor_to_protection_class(armor.acid, compare_to?.armor?.acid)]"
		if(flags_cover & HEADCOVERSMOUTH)
			readout += "<br /><b>COVERAGE</b>"
			readout += "<br />It will block Facehuggers."
			/* We dont have the tooltips for this
			readout += "<span class='tooltip'>Because this item is worn on the head and is covering the mouth, it will block facehugger proboscides, killing them</span>."
			*/

		readout += "</span>"

		to_chat(usr, EXAMINE_BLOCK("[readout.Join()]"))

/**
 * Rounds armor_value down to the nearest 10, divides it by 10 and then converts it to Roman numerals.
 *
 * Arguments:
 * * armor_value - Number we're converting
 */
/obj/item/clothing/proc/armor_to_protection_class(armor_value, compare_value)
	if (armor_value < 0)
		. = "-"
	if (armor_value == 0)
		. += "None"
	else
		. += "\Roman[round(abs(armor_value), 10) / 10]"
	if (!isnull(compare_value))
		if (armor_value > compare_value)
			. = "<span class='green'>[.]</span>"
		else if (armor_value < compare_value)
			. = "<span class='red'>[.]</span>"

/obj/item/clothing/obj_break(damage_flag)
	if(!damaged_clothes)
		update_clothes_damaged_state(TRUE)
	if(ismob(loc)) //It's not important enough to warrant a message if nobody's wearing it
		var/mob/M = loc
		to_chat(M, "<span class='warning'>Your [name] starts to fall apart!</span>")


//This mostly exists so subtypes can call appriopriate update icon calls on the wearer.
/obj/item/clothing/proc/update_clothes_damaged_state(damaging = TRUE)
	if(damaging)
		damaged_clothes = 1
	else
		damaged_clothes = 0

/obj/item/clothing/update_overlays()
	. = ..()
	if(!damaged_clothes)
		return

	var/initial_icon = initial(icon)
	var/index = "[REF(initial_icon)]-[initial(icon_state)]"
	var/static/list/damaged_clothes_icons = list()
	var/icon/damaged_clothes_icon = damaged_clothes_icons[index]
	if(!damaged_clothes_icon)
		damaged_clothes_icon = icon(icon, icon_state, null, 1)
		damaged_clothes_icon.Blend("#fff", ICON_ADD) 	//fills the icon_state with white (except where it's transparent)
		damaged_clothes_icon.Blend(icon('icons/effects/item_damage.dmi', "itemdamaged"), ICON_MULTIPLY) //adds damage effect and the remaining white areas become transparant
		damaged_clothes_icon = fcopy_rsc(damaged_clothes_icon)
		damaged_clothes_icons[index] = damaged_clothes_icon
	. += damaged_clothes_icon


/*
SEE_SELF  // can see self, no matter what
SEE_MOBS  // can see all mobs, no matter what
SEE_OBJS  // can see all objs, no matter what
SEE_TURFS // can see all turfs (and areas), no matter what
SEE_PIXELS// if an object is located on an unlit area, but some of its pixels are
          // in a lit area (via pixel_x,y or smooth movement), can see those pixels
BLIND     // can't see anything
*/

/proc/generate_female_clothing(index,t_color,icon,type)
	var/icon/female_clothing_icon	= icon("icon"=icon, "icon_state"=t_color)
	var/icon/female_s				= icon("icon"='icons/mob/clothing/uniform.dmi', "icon_state"="[(type == FEMALE_UNIFORM_FULL) ? "female_full" : "female_top"]")
	female_clothing_icon.Blend(female_s, ICON_MULTIPLY)
	female_clothing_icon 			= fcopy_rsc(female_clothing_icon)
	GLOB.female_clothing_icons[index] = female_clothing_icon

/obj/item/clothing/under/proc/set_sensors(mob/user)
	var/mob/M = user
	if(M.stat)
		return
	if(!can_use(M))
		return
	if(src.has_sensor == LOCKED_SENSORS)
		to_chat(user, "<span class='warning'>The controls are locked.</span>")
		return FALSE
	if(src.has_sensor == BROKEN_SENSORS)
		to_chat(user, "<span class='warning'>The sensors have shorted out!</span>")
		return FALSE
	if(src.has_sensor <= NO_SENSORS)
		to_chat(user, "<span class='warning'>This suit does not have any sensors.</span>")
		return FALSE

	var/list/modes = list("Off", "Binary vitals", "Exact vitals", "Tracking beacon")
	var/switchMode = input("Select a sensor mode:", "Suit Sensor Mode", modes[sensor_mode + 1]) in modes
	if(get_dist(user, src) > 1)
		to_chat(user, "<span class='warning'>You have moved too far away!</span>")
		return
	var/sensor_selection = modes.Find(switchMode) - 1

	if (src.loc == user)
		switch(sensor_selection)
			if(SENSORS_OFF)
				to_chat(user, "<span class='notice'>You disable your suit's remote sensing equipment.</span>")
			if(SENSORS_BINARY)
				to_chat(user, "<span class='notice'>Your suit will now only report whether you are alive or dead.</span>")
			if(SENSORS_VITALS)
				to_chat(user, "<span class='notice'>Your suit will now only report your exact vital lifesigns.</span>")
			if(SENSORS_TRACKING)
				to_chat(user, "<span class='notice'>Your suit will now report your exact vital lifesigns as well as your coordinate position.</span>")
		update_sensors(sensor_selection)
	else if(istype(src.loc, /mob))
		var/mob/living/carbon/human/wearer = src.loc
		wearer.visible_message("<span class='notice'>[user] tries to set [wearer]'s sensors.</span>", \
						 "<span class='warning'>[user] is trying to set your sensors.</span>", null, COMBAT_MESSAGE_RANGE)
		if(do_after(user, SENSOR_CHANGE_DELAY, wearer))
			switch(sensor_selection)
				if(SENSORS_OFF)
					wearer.visible_message("<span class='warning'>[user] disables [wearer]'s remote sensing equipment.</span>", \
						 "<span class='warning'>[user] disables your remote sensing equipment.</span>", null, COMBAT_MESSAGE_RANGE)
				if(SENSORS_BINARY)
					wearer.visible_message("<span class='notice'>[user] turns [wearer]'s remote sensors to binary.</span>", \
						 "<span class='notice'>[user] turns your remote sensors to binary.</span>", null, COMBAT_MESSAGE_RANGE)
				if(SENSORS_VITALS)
					wearer.visible_message("<span class='notice'>[user] turns [wearer]'s remote sensors to track vitals.</span>", \
						 "<span class='notice'>[user] turns your remote sensors to track vitals.</span>", null, COMBAT_MESSAGE_RANGE)
				if(SENSORS_TRACKING)
					wearer.visible_message("<span class='notice'>[user] turns [wearer]'s remote sensors to maximum.</span>", \
						 "<span class='notice'>[user] turns your remote sensors to maximum.</span>", null, COMBAT_MESSAGE_RANGE)
			update_sensors(sensor_selection)
			log_combat(user, wearer, "changed sensors to [switchMode]")
	if(ishuman(loc) || ismonkey(loc))
		var/mob/living/carbon/human/H = loc
		if(H.w_uniform == src)
			H.update_suit_sensors()

/obj/item/clothing/under/verb/toggle()
	set name = "Adjust Suit Sensors"
	set category = "Object"
	set src in usr
	set_sensors(usr)

/obj/item/clothing/under/attack_hand(mob/user)
	if(attached_accessory && ispath(attached_accessory.pocket_storage_component_path) && loc == user)
		attached_accessory.attack_hand(user)
		return
	..()

/obj/item/clothing/under/AltClick(mob/user)
	if(!istype(user) || !user.canUseTopic(src, BE_CLOSE, ismonkey(user)))
		return
	else
		if(attached_accessory)
			remove_accessory(user)
		else
			rolldown()

/obj/item/clothing/under/verb/jumpsuit_adjust()
	set name = "Adjust Jumpsuit Style"
	set category = null
	set src in usr
	rolldown()

/obj/item/clothing/under/proc/rolldown()
	if(!can_use(usr))
		return
	if(!can_adjust)
		to_chat(usr, "<span class='warning'>You cannot wear this suit any differently!</span>")
		return
	if(toggle_jumpsuit_adjust())
		to_chat(usr, "<span class='notice'>You adjust the suit to wear it more casually.</span>")
	else
		to_chat(usr, "<span class='notice'>You adjust the suit back to normal.</span>")
	if(ishuman(usr))
		var/mob/living/carbon/human/H = usr
		H.update_inv_w_uniform()
		H.update_body()

/obj/item/clothing/under/proc/toggle_jumpsuit_adjust()
	if(adjusted == DIGITIGRADE_STYLE)
		return
	adjusted = !adjusted
	if(adjusted)
		envirosealed = FALSE
		if(fitted != FEMALE_UNIFORM_TOP)
			fitted = NO_FEMALE_UNIFORM
		if(!alt_covers_chest) // for the special snowflake suits that expose the chest when adjusted
			body_parts_covered &= ~CHEST
	else
		fitted = initial(fitted)
		envirosealed = initial(envirosealed)
		if(!alt_covers_chest)
			body_parts_covered |= CHEST
	return adjusted

/obj/item/clothing/proc/weldingvisortoggle(mob/user) //proc to toggle welding visors on helmets, masks, goggles, etc.
	if(!can_use(user))
		return FALSE

	visor_toggling()

	to_chat(user, "<span class='notice'>You adjust \the [src] [up ? "up" : "down"].</span>")

	if(iscarbon(user))
		var/mob/living/carbon/C = user
		C.head_update(src, forced = TRUE)
	update_action_buttons()
	return TRUE

/obj/item/clothing/proc/visor_toggling() //handles all the actual toggling of flags
	up = !up
	clothing_flags ^= visor_flags
	flags_inv ^= visor_flags_inv
	flags_cover ^= initial(flags_cover)
	icon_state = "[initial(icon_state)][up ? "up" : ""]"
	if(visor_vars_to_toggle & VISOR_FLASHPROTECT)
		flash_protect ^= initial(flash_protect)
	if(visor_vars_to_toggle & VISOR_TINT)
		tint ^= initial(tint)

/obj/item/clothing/head/helmet/space/plasmaman/visor_toggling() //handles all the actual toggling of flags
	up = !up
	clothing_flags ^= visor_flags
	flags_inv ^= visor_flags_inv
	icon_state = "[initial(icon_state)]"
	if(visor_vars_to_toggle & VISOR_FLASHPROTECT)
		flash_protect ^= initial(flash_protect)
	if(visor_vars_to_toggle & VISOR_TINT)
		tint ^= initial(tint)

/obj/item/clothing/proc/can_use(mob/user)
	if(user && ismob(user))
		if(!user.incapacitated())
			return 1
	return 0


/obj/item/clothing/obj_destruction(damage_flag)
	if(damage_flag == BOMB || damage_flag == MELEE)
		var/turf/T = get_turf(src)
		spawn(1) //so the shred survives potential turf change from the explosion.
			var/obj/effect/decal/cleanable/shreds/Shreds = new(T)
			Shreds.desc = "The sad remains of what used to be [name]."
		deconstruct(FALSE)
	else
		..()

/obj/item/clothing/get_armor_rating(d_type, mob/wearer)
	. = ..()
	if(high_pressure_multiplier == 1)
		return
	var/turf/T = get_turf(wearer)
	if(!T || !(d_type in high_pressure_multiplier_types))
		return
	if(!lavaland_equipment_pressure_check(T))
		. *= high_pressure_multiplier

#undef SENSORS_OFF
#undef SENSORS_BINARY
#undef SENSORS_VITALS
#undef SENSORS_TRACKING
#undef SENSOR_CHANGE_DELAY
