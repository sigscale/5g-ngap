%%% ngap.hrl

-record(ue_connection,
		{amf_id :: 0..1099511627775,
		ran_id :: 0..4294967295,
		node :: atom(),
		endpoint :: pid(),
		association :: pid(),
		stream :: pid()}).

