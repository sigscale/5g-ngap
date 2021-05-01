%% amf.hrl

-type tac() :: <<_:16>> | <<_:24>>.
-type snssai() :: <<_:8>> | <<_:32>>.
-type access_type() :: '3gpp' | non3gpp.

-type eutra_location() :: #{tai := binary(),
		ecgi := binary(),
		age_of_location_information => non_neg_integer(),
		ue_location_timestamp => pos_integer(),
		geographical_information => string(),
		geodetic_information => string(),
		global_ngenb_id => binary()}.

-type nr_location() :: #{tai := binary(),
		ncgi := binary(),
		age_of_location_information => non_neg_integer(),
		ue_location_timestamp => pos_integer(),
		geographical_information => string(),
		geodetic_information => string(),
		global_gnb_id => binary()}.

-type n3ga_location() :: #{tai => binary(),
		n3_iwf_id => binary(),
		ue_ipv4_address => inet:ip_address(),
		ue_ipv6_address => inet:ip_address(),
		port_number => inet:port_number()}.

-type mm_context() :: #{access_type := access_type(),
		nas_security_mode => #{integrity_algorithm := nai0 | nai1 | nai2 | nai3,
				ciphering_algorithm := nea0 | nea1 | nea2 | nea3},
		nas_downlink_count => non_neg_integer(),
		nas_uplink_count => non_neg_integer(),
		ue_security_capability => binary(),
		s1_ue_network_capability => binary(),
		allowed_nssai => [snssai()],
		nssai_mapping_list => [#{mapped_snssai := snssai(),
				hsnssai => snssai()}],
		ns_instance_list => [binary()],
		expected_ue_behavior => #{exp_move_trajectory
				:= [#{eutra_location => eutra_location(),
				nr_location => nr_location(),
				n3ga_lcation => n3ga_location()}],
				validity_time := pos_integer()}}.

-type session_context() :: #{pdu_session_id := 0..255,
		sm_context_ref := string(),
		snssai := snssai(),
		dnn := string(),
		access_type := access_type(),
		allocated_ebi_list => [#{eps_bearer_id := 0..15,
				arp := #{priority_level := 1..15,
				preempt_cap := not_preempt | may_preempt,
				preempt_vuln := not_peemptable | preemptable}}],
		hsmf_id => string(),
		vsmf_id => string(),
		ns_instance => string(),
		smf_service_instance_id => string()}.

-type ue_context() :: #{supi => string(),
				supi_unauth_ind => boolean(),
				gpsi_list => [string(),
				pei => string(),
				udm_group_id => string(),
				ausf_group_id => string(),
				routing_indicator => string(),
				group_list => [string()],
				drx_parameter => binary(),
				sub_rfsp => non_neg_integer(),
				used_rfsp => non_neg_integer(),
				sub_ue_ambr => {Uplink :: string(), Downlink :: string()},
				sms_support => '3gpp' | non3gpp | both | none,
				smsf_id => string(),
				seaf_data => #{ng_ksi := #{tsc := native | mapped , ksi := 0..6},
						key_amf := #{key_type := kamf | kprimeamf, key_val := string()},
						nh => string(),
						ncc => 0..7,
						key_amf_change_ind => boolean(),
						key_amf_h_derivation_ind => boolean()},
				'5g_mm_capability' => boolean(),
				pcf_id => string(),
				pcf_am_policy_uri => string(),
				am_policy_req_trigger_list => [location_change | pra_change | sari_change
						| rfsp_index_change | allowed_nssai_change],
				pcf_ue_policy_uri => string(),
				ue_policy_req_trigger_list => [location_change | pra_change | sari_change
						| rfsp_index_change | allowed_nssai_change],
				hpcf_id => string(),
				restricted_rat_list => [nr | eutra | wlan | virtual],
				forbidden_area_list => [#{tacs => [tac()], area_code => string()}],
				service_area_restriction => #{restriction_type  => allowed_areas | not_allowed_areas,
						areas => [#{tacs => [tac()], area_code => string()}],
						max_num_of_tas =>  non_neg_integer(),
						max_num_of_tas_for_not_allowed_areas => non_neg_integer()},
				restricted_core_nw_type_list => [ '5gc' | epc],
				event_subscription_list => [map()],
				mm_context_ist => [mm_context()],
				session_context_list => [session_context()],
				trace_data => map()}}).

-record(ue_context,
		{amf_id :: 0..1099511627775,
		ran_id :: 0..4294967295,
		imsi :: binary(),
		imei :: binary(),
		context :: ue_context()}.

