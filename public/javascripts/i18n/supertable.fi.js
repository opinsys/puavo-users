I18n.translations || (I18n.translations = {});

I18n.translations["fi"] = I18n.extend((I18n.translations["fi"] || {}),
{
    supertable: {
        empty: "(Ei mitään näytettävää)",

        control: {
            select_columns: "Valitse sarakkeet...",
            select_columns_title: "Valitse näkyvät sarakkeet ja missä järjestyksessä",
            download_csv: "Lataa CSV...",
            download_csv_title: "Lataa näkyvän taulukon sisältö CSV-tiedostona",
            reload: "Päivitä",
            reload_title: "Päivitä taulukon sisältö ilman että koko sivu ladataan uudelleen",
            fetching: "Päivitetään...",
            failed: "Epäonnistui!",
            network_error: "Verkkovirhe?",
            server_error: "Palvelin palautti virheen ",
            timeout: "Aikakatkaisu, yritä uudelleen myöhemmin",
            json_fail: "JSONin tulkkaus epäonnistui, katso konsolia",
            status: "${total} ${itemName} yhteensä, ${filtered} suodatettu, ${visible} näkyvissä",
            filtering_main_enabled: "Suodatus päällä",
            filtering_main_enabled_title: "Näytä vain tietyn kriteerin täyttävät rivit",
            filtering_main_reverse: "Käänteinen täsmäys",
            filtering_main_reverse_title: "Näytä vain rivit jotka EIVÄT täsmää annettuihin kriteereihin",
            filtering_presets: "Pohjat:",
            filtering_presets_title: "Käytä valmiiksi luotuja suodattimia",
            filtering_select: "(Valitse)",
            filtering_reset: "(Nollaa)",

            filter: {
                placeholder_string: "Regexp-tekstijono",
                placeholder_integer: "Numero",
                title_boolean: "Tosi",
                placeholder_unixtime_year: "VVVV",
                placeholder_unixtime_month: "KK",
                placeholder_unixtime_day: "PP",
                placeholder_unixtime_hour: "TT",
                placeholder_unixtime_minute: "MM",

                title_active: "Onko suodatinrivi aktiivinen? Jos ruksi on harmaa, suodatin on virheellinen/vajaa ja sitä ei käytetä.",
                title_column: "Mihin kenttään täsmäys kohdistetaan",
                title_operator: "Vertailun tyyppi",
                title_button_add: "Lisää uusi suodatinrivi listan loppuun",
                title_button_remove: "Poista tämä suodatinrivi",
            },
        },

        // Sadly we can't get these from the main translations YAML file
        actions: {
            title: "Toiminnot",
            edit: "Muokkaa...",
            remove_confirm: "Oletko varma?",
            remove: "Poista",
        },

        column_editor: {
            title: "Valitse sarakkeet",
            save: "Tallenna",
            cancel: "Peruuta",
            moveUp: "Siirrä ylös",
            moveDown: "Siirrä alas",
            reset: "Oletukset",
            all: "Ruksaa kaikki",
            visible: "Näytä?",
            name: "Nimi",
        },

        misc: {
            unset_group_type: "(Puuttuu / ei asetettu)",
        },
    }
});