use work.all;

configuration rtl of mk3blit is

	for rtl
		for e_fb_HDMI : fb_HDMI 
			use entity work.fb_HDMI(rtl);
		end for;
	end for;

end rtl;