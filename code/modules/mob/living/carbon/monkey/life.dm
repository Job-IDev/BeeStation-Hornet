/mob/living/carbon/monkey/handle_mutations_and_radiation()
	if(radiation)
		if(radiation > RAD_MOB_KNOCKDOWN && prob(RAD_MOB_KNOCKDOWN_PROB))
			if(!IsParalyzed())
				emote("collapse")
			Paralyze(RAD_MOB_KNOCKDOWN_AMOUNT)
			to_chat(src, span_danger("You feel weak."))
		if(radiation > RAD_MOB_MUTATE)
			if(prob(2))
				to_chat(src, span_danger("You mutate!"))
				easy_random_mutate(NEGATIVE+MINOR_NEGATIVE)
				emote("gasp")
				domutcheck()

				if(radiation > RAD_MOB_MUTATE * 1.5)
					switch(rand(1, 3))
						if(1)
							gorillize()
						if(2)
							humanize(TR_KEEPITEMS | TR_KEEPVIRUS | TR_DEFAULTMSG | TR_KEEPDAMAGE | TR_KEEPORGANS)
						if(3)
							var/obj/item/bodypart/BP = pick(bodyparts)
							if(BP.body_part != HEAD && BP.body_part != CHEST)
								if(BP.dismemberable)
									BP.dismember()
							take_bodypart_damage(100, 0, 0)
					return
		if(radiation > RAD_MOB_VOMIT && prob(RAD_MOB_VOMIT_PROB))
			vomit(10, TRUE)
	return ..()

/mob/living/carbon/monkey/handle_breath_temperature(datum/gas_mixture/breath)
	if(abs(get_body_temp_normal() - breath.return_temperature()) > 50)
		switch(breath.return_temperature())
			if(-INFINITY to 120)
				adjustFireLoss(3)
			if(120 to 200)
				adjustFireLoss(1.5)
			if(200 to 260)
				adjustFireLoss(0.5)
			if(360 to 400)
				adjustFireLoss(2)
			if(400 to 1000)
				adjustFireLoss(3)
			if(1000 to INFINITY)
				adjustFireLoss(8)

	. = ..() // interact with body heat after dealing with the hot air

/mob/living/carbon/monkey/handle_environment(datum/gas_mixture/environment)
	// Run base mob body temperature proc before taking damage
	// this balances body temp to the enviroment and natural stabilization
	. = ..()

	if(bodytemperature > BODYTEMP_HEAT_DAMAGE_LIMIT && !HAS_TRAIT(src, TRAIT_RESISTHEAT))
		remove_movespeed_modifier(/datum/movespeed_modifier/monkey_temperature_speedmod)
		switch(bodytemperature)
			if(360 to 400)
				throw_alert("temp", /atom/movable/screen/alert/hot, 1)
				apply_damage(HEAT_DAMAGE_LEVEL_1, BURN)
			if(400 to 460)
				throw_alert("temp", /atom/movable/screen/alert/hot, 2)
				apply_damage(HEAT_DAMAGE_LEVEL_2, BURN)
			if(460 to INFINITY)
				throw_alert("temp", /atom/movable/screen/alert/hot, 3)
				if(on_fire)
					apply_damage(HEAT_DAMAGE_LEVEL_3, BURN)
				else
					apply_damage(HEAT_DAMAGE_LEVEL_2, BURN)

	else if(bodytemperature < BODYTEMP_COLD_DAMAGE_LIMIT && !HAS_TRAIT(src, TRAIT_RESISTCOLD))
		if(!istype(loc, /obj/machinery/cryo_cell))
			add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/monkey_temperature_speedmod, multiplicative_slowdown = ((BODYTEMP_COLD_DAMAGE_LIMIT - bodytemperature) / COLD_SLOWDOWN_FACTOR))
			switch(bodytemperature)
				if(200 to BODYTEMP_COLD_DAMAGE_LIMIT)
					throw_alert("temp", /atom/movable/screen/alert/cold, 1)
					apply_damage(COLD_DAMAGE_LEVEL_1, BURN)
				if(120 to 200)
					throw_alert("temp", /atom/movable/screen/alert/cold, 2)
					apply_damage(COLD_DAMAGE_LEVEL_2, BURN)
				if(-INFINITY to 120)
					throw_alert("temp", /atom/movable/screen/alert/cold, 3)
					apply_damage(COLD_DAMAGE_LEVEL_3, BURN)
		else
			clear_alert("temp")

	else
		remove_movespeed_modifier(/datum/movespeed_modifier/monkey_temperature_speedmod)
		clear_alert("temp")

	//Account for massive pressure differences

	var/pressure = environment.return_pressure()
	var/adjusted_pressure = calculate_affecting_pressure(pressure) //Returns how much pressure actually affects the mob.
	switch(adjusted_pressure)
		if(HAZARD_HIGH_PRESSURE to INFINITY)
			adjustBruteLoss( min( ( (adjusted_pressure / HAZARD_HIGH_PRESSURE) -1 )*PRESSURE_DAMAGE_COEFFICIENT , MAX_HIGH_PRESSURE_DAMAGE) )
			throw_alert("pressure", /atom/movable/screen/alert/highpressure, 2)
		if(WARNING_HIGH_PRESSURE to HAZARD_HIGH_PRESSURE)
			throw_alert("pressure", /atom/movable/screen/alert/highpressure, 1)
		if(WARNING_LOW_PRESSURE to WARNING_HIGH_PRESSURE)
			clear_alert("pressure")
		if(HAZARD_LOW_PRESSURE to WARNING_LOW_PRESSURE)
			throw_alert("pressure", /atom/movable/screen/alert/lowpressure, 1)
		else
			if(HAS_TRAIT(src, TRAIT_RESISTLOWPRESSURE))
				clear_alert("pressure")
			else
				adjustBruteLoss( LOW_PRESSURE_DAMAGE )
				throw_alert("pressure", /atom/movable/screen/alert/lowpressure, 2)

	return

/mob/living/carbon/monkey/calculate_affecting_pressure(pressure)
	if (head && isclothing(head))
		var/obj/item/clothing/CH = head
		if (CH.clothing_flags & STOPSPRESSUREDAMAGE)
			return ONE_ATMOSPHERE
	return pressure

/mob/living/carbon/monkey/handle_random_events()
	if (prob(1) && prob(2))
		emote("scratch")

/mob/living/carbon/monkey/has_smoke_protection()
	if(wear_mask)
		if(wear_mask.clothing_flags & BLOCK_GAS_SMOKE_EFFECT)
			return 1

/mob/living/carbon/monkey/handle_fire()
	. = ..()
	if(.) //if the mob isn't on fire anymore
		return

	//the fire tries to damage the exposed clothes and items
	var/list/burning_items = list()
	//HEAD//
	var/obscured = check_obscured_slots(TRUE)
	if(wear_mask && !(obscured & ITEM_SLOT_MASK))
		burning_items += wear_mask
	if(wear_neck && !(obscured & ITEM_SLOT_NECK))
		burning_items += wear_neck
	if(head)
		burning_items += head

	if(back)
		burning_items += back

	for(var/obj/item/I as() in burning_items)
		I.fire_act((fire_stacks * 50)) //damage taken is reduced to 2% of this value by fire_act()

	if(!head?.max_heat_protection_temperature || head.max_heat_protection_temperature < FIRE_IMMUNITY_MAX_TEMP_PROTECT)
		adjust_bodytemperature(BODYTEMP_HEATING_MAX)
		SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "on_fire", /datum/mood_event/on_fire)
