/* generated from login.glade, do not modify */
namespace Zed.Data.Login {
	public static const string UI_XML = "<?xml version=\"1.0\" ?>" +
		"<interface><object class=\"GtkTable\" id=\"table\">" +
			"<property name=\"visible\">True</property>" +
			"<property name=\"n_rows\">4</property>" +
			"<property name=\"n_columns\">2</property>" +
			"<property name=\"column_spacing\">6</property>" +
			"<property name=\"row_spacing\">4</property>" +
			"<child>" +
				"<object class=\"GtkLabel\" id=\"username_label\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"xalign\">1</property>" +
					"<property name=\"label\" translatable=\"yes\">Username:</property>" +
				"</object>" +
				"<packing>" +
					"<property name=\"top_attach\">1</property>" +
					"<property name=\"bottom_attach\">2</property>" +
					"<property name=\"y_options\">GTK_FILL</property>" +
				"</packing>" +
			"</child>" +
			"<child>" +
				"<object class=\"GtkLabel\" id=\"password_label\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"xalign\">1</property>" +
					"<property name=\"label\" translatable=\"yes\">Password:</property>" +
				"</object>" +
				"<packing>" +
					"<property name=\"top_attach\">2</property>" +
					"<property name=\"bottom_attach\">3</property>" +
					"<property name=\"y_options\"/>" +
				"</packing>" +
			"</child>" +
			"<child>" +
				"<object class=\"GtkLabel\" id=\"welcome_label\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"yalign\">0.93000000715255737</property>" +
					"<property name=\"label\" translatable=\"yes\">&lt;span foreground=&quot;blue&quot; size=&quot;xx-large&quot;&gt;Welcome to Frida!&lt;/span&gt;</property>" +
					"<property name=\"use_markup\">True</property>" +
				"</object>" +
				"<packing>" +
					"<property name=\"right_attach\">2</property>" +
				"</packing>" +
			"</child>" +
			"<child>" +
				"<object class=\"GtkAlignment\" id=\"username_alignment\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"xalign\">0</property>" +
					"<property name=\"xscale\">0</property>" +
					"<child>" +
						"<object class=\"GtkEntry\" id=\"username_entry\">" +
							"<property name=\"visible\">True</property>" +
							"<property name=\"can_focus\">True</property>" +
							"<property name=\"activates_default\">True</property>" +
						"</object>" +
					"</child>" +
				"</object>" +
				"<packing>" +
					"<property name=\"left_attach\">1</property>" +
					"<property name=\"right_attach\">2</property>" +
					"<property name=\"top_attach\">1</property>" +
					"<property name=\"bottom_attach\">2</property>" +
					"<property name=\"x_options\">GTK_FILL</property>" +
					"<property name=\"y_options\"/>" +
				"</packing>" +
			"</child>" +
			"<child>" +
				"<object class=\"GtkAlignment\" id=\"password_alignment\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"xalign\">0</property>" +
					"<property name=\"xscale\">0</property>" +
					"<child>" +
						"<object class=\"GtkEntry\" id=\"password_entry\">" +
							"<property name=\"visible\">True</property>" +
							"<property name=\"can_focus\">True</property>" +
							"<property name=\"activates_default\">True</property>" +
						"</object>" +
					"</child>" +
				"</object>" +
				"<packing>" +
					"<property name=\"left_attach\">1</property>" +
					"<property name=\"right_attach\">2</property>" +
					"<property name=\"top_attach\">2</property>" +
					"<property name=\"bottom_attach\">3</property>" +
					"<property name=\"y_options\">GTK_FILL</property>" +
				"</packing>" +
			"</child>" +
			"<child>" +
				"<object class=\"GtkAlignment\" id=\"signin_alignment\">" +
					"<property name=\"visible\">True</property>" +
					"<property name=\"yalign\">0.05000000074505806</property>" +
					"<property name=\"xscale\">0.039999999105930328</property>" +
					"<property name=\"yscale\">0.019999999552965164</property>" +
					"<child>" +
						"<object class=\"GtkButton\" id=\"sign_in_button\">" +
							"<property name=\"visible\">True</property>" +
							"<property name=\"can_focus\">True</property>" +
							"<property name=\"can_default\">True</property>" +
							"<property name=\"receives_default\">True</property>" +
							"<property name=\"label\" translatable=\"yes\">Sign In</property>" +
						"</object>" +
					"</child>" +
				"</object>" +
				"<packing>" +
					"<property name=\"right_attach\">2</property>" +
					"<property name=\"top_attach\">3</property>" +
					"<property name=\"bottom_attach\">4</property>" +
				"</packing>" +
			"</child>" +
		"</object></interface>";
}
