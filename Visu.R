install.packages(c(
  "shiny",
  "ggplot2",
  "dplyr",
  "bslib",
  "RMariaDB",
  "plotly",
  "lubridate"
))

#sudo apt install libmariadb-dev libmariadb-dev-compat build-essential
#sudo apt install libcurl4-openssl-dev libssl-dev libxml2-dev

library(shiny)
library(ggplot2)
library(dplyr)
library(bslib)
library(RMariaDB)
library(plotly)
library(lubridate) 

# ==============================================================================
# 1. PARAMÈTRES DE TA BASE DE DONNÉES
# ==============================================================================
DB_HOST <- "mysql"
DB_USER <- "app_user"          # <-- A VERIFIER
DB_PASS <- "app_password"      # <-- A VERIFIER
DB_NAME <- "app_db"            # <-- A VERIFIER

# ==============================================================================
# 2. FONCTION DE CONNEXION 
# ==============================================================================
charger_les_donnees <- function() {
  
  con <- dbConnect(RMariaDB::MariaDB(), host = DB_HOST, user = DB_USER, password = DB_PASS, dbname = DB_NAME)
  df_ventes_brut <- dbGetQuery(con, "SELECT * FROM historique_vente")
  df_articles_brut <- dbGetQuery(con, "SELECT * FROM tpe_code_article")
  df_stocks_brut <- dbGetQuery(con, "SELECT * FROM stock")
  dbDisconnect(con)
  
  # --- ÉTAPE A : Créer les STOCKS parfaits (La référence absolue) ---
  stocks_finals <- left_join(df_stocks_brut, df_articles_brut, by = "code_article")
  stocks_finals <- rename(stocks_finals, Produit = nom_tpe, Catégorie = type)
  stocks_finals$Stock_Actuel <- stocks_finals$quantite
  
  # --- ÉTAPE B : Créer un "Catalogue de vérité" depuis les stocks ---
  # On extrait 1 nom de produit = 1 seule catégorie exacte
  catalogue_verite <- stocks_finals %>% 
    select(Produit, Catégorie) %>% 
    filter(!is.na(Produit)) %>% 
    distinct(Produit, .keep_all = TRUE)
  
  # --- ÉTAPE C : Traiter les VENTES en forçant la bonne catégorie ---
  ventes_finales <- df_ventes_brut %>% rename(Produit = nom_tpe)
  
  # inner_join : On ne garde que les ventes qui matchent avec le catalogue officiel
  ventes_finales <- inner_join(ventes_finales, catalogue_verite, by = "Produit")
  ventes_finales$Date <- as.Date(ventes_finales$datetime) 
  
  return(list(ventes = ventes_finales, stock = stocks_finals))
}

# Lancement au démarrage
donnees_foyer <- charger_les_donnees()
df_ventes <- donnees_foyer$ventes
df_stock <- donnees_foyer$stock


# ==============================================================================
# 3. INTERFACE VISUELLE (UI)
# ==============================================================================
ui <- page_navbar(
  title = "📊 Dashboard Foyer UTT",
  theme = bs_theme(bootswatch = "flatly", primary = "#2C3E50"),
  
  sidebar = sidebar(
    title = "Base de données",
    actionButton("refresh", "🔄 Actualiser les données", class = "btn-success"),
    hr()
  ),
  
  # --- Onglet STOCKS ---
  nav_panel("📦 Stocks",
            sidebarLayout(
              sidebarPanel(
                selectInput("filtre_cat_stock", "Filtrer par Catégorie :", 
                            choices = c("Toutes les catégories", unique(df_stock$Catégorie)))
              ),
              mainPanel(
                card(
                  card_header("État des stocks par rayon"),
                  plotlyOutput("plot_stock", height = "600px") 
                )
              )
            )
  ),
  
  # --- Onglet VENTES ---
  nav_panel("📈 Ventes",
            sidebarLayout(
              sidebarPanel(
                # On utilise les catégories du STOCK (qui sont complètes) !
                selectInput("filtre_cat_ventes", "Filtrer par Catégorie :", 
                            choices = c("Toutes les catégories", unique(df_stock$Catégorie))),
                
                uiOutput("menu_produit_dynamique"),
                
                hr(),
                
                radioButtons("choix_temps", "Analyser la tendance :", 
                             choices = c("Par Heure" = "jour", 
                                         "Par Jour" = "semaine", 
                                         "Par Mois" = "mois"), 
                             selected = "jour")
              ),
              mainPanel(
                card(
                  card_header("Évolution temporelle des ventes"),
                  plotlyOutput("plot_ventes", height = "500px")
                )
              )
            )
  )
)


# ==============================================================================
# 4. LE SERVEUR
# ==============================================================================
server <- function(input, output, session) {
  
  data_reactive <- reactiveValues(ventes = df_ventes, stock = df_stock)
  
  observeEvent(input$refresh, {
    showNotification("Téléchargement des données en cours...", type = "warning", duration = 2)
    nouvelles_donnees <- charger_les_donnees()
    data_reactive$ventes <- nouvelles_donnees$ventes
    data_reactive$stock <- nouvelles_donnees$stock
    showNotification("Mise à jour terminée !", type = "message", duration = 3)
  })
  
  # --- Graphique STOCKS ---
  output$plot_stock <- renderPlotly({
    stock_filtre <- data_reactive$stock
    
    if (input$filtre_cat_stock != "Toutes les catégories") {
      stock_filtre <- stock_filtre %>% filter(Catégorie == input$filtre_cat_stock)
    }
    
    stock_filtre <- stock_filtre %>% arrange(Stock_Actuel)
    stock_filtre$Produit <- factor(stock_filtre$Produit, levels = stock_filtre$Produit)
    
    # Alternance des couleurs
    stock_filtre <- stock_filtre %>% mutate(Couleur_Ligne = ifelse(row_number() %% 2 == 0, "Pair", "Impair"))
    
    p_stock <- ggplot(stock_filtre, aes(x = Produit, y = Stock_Actuel, fill = Couleur_Ligne, 
                                        text = paste("Produit:", Produit, "<br>En stock:", Stock_Actuel))) +
      geom_col() +
      scale_fill_manual(values = c("Pair" = "#2980B9", "Impair" = "#7FB3D5")) +
      coord_flip() + 
      theme_minimal(base_size = 14) +
      theme(legend.position = "none", axis.text.y = element_text(face = "bold", size = 11)) +
      labs(x = "", y = "Quantité en stock")
    
    ggplotly(p_stock, tooltip = "text") %>% layout(showlegend = FALSE)
  })
  
  # --- Menu DYNAMIQUE VENTES ---
  output$menu_produit_dynamique <- renderUI({
    # On se base sur le STOCK pour avoir tout le catalogue !
    v_data <- data_reactive$stock 
    
    if (input$filtre_cat_ventes == "Toutes les catégories") {
      liste_produits <- unique(v_data$Produit)
    } else {
      liste_produits <- v_data %>% 
        filter(Catégorie == input$filtre_cat_ventes) %>% 
        pull(Produit) %>% 
        unique()
    }
    selectInput("choix_produit", "Sélectionner un produit :", 
                choices = c("Tous les produits", liste_produits))
  })
  
  # --- Graphique VENTES ---
  output$plot_ventes <- renderPlotly({
    req(input$choix_produit) 
    
    ventes_filtrees <- data_reactive$ventes 
    
    if (input$filtre_cat_ventes != "Toutes les catégories") {
      ventes_filtrees <- ventes_filtrees %>% filter(Catégorie == input$filtre_cat_ventes)
    }
    if (input$choix_produit != "Tous les produits") {
      ventes_filtrees <- ventes_filtrees %>% filter(Produit == input$choix_produit)
    }
    
    if (nrow(ventes_filtrees) == 0) {
      p_vide <- ggplot() + 
        annotate("text", x = 1, y = 1, label = "Aucune vente pour ce produit/cette période.") +
        theme_void()
      return(ggplotly(p_vide))
    }
    
    if (input$choix_temps == "jour") {
      ventes_filtrees <- ventes_filtrees %>% mutate(Periode = format(as.POSIXct(datetime), "%Hh"))
      titre_axe <- "Heure de la journée"
      
    } else if (input$choix_temps == "semaine") {
      ventes_filtrees <- ventes_filtrees %>% mutate(Periode = wday(as.POSIXct(datetime), label = TRUE, abbr = FALSE, week_start = 1))
      titre_axe <- "Jour de la semaine"
      
    } else if (input$choix_temps == "mois") {
      ventes_filtrees <- ventes_filtrees %>% mutate(Periode = as.Date(cut(Date, breaks = "month")))
      titre_axe <- "Mois"
    }
    
    # On ajoute Produit dans le group_by
    ventes_groupees <- ventes_filtrees %>% 
      group_by(Periode, Produit) %>% 
      summarise(Total_Vendus = n(), .groups = "drop")
    
    if (input$choix_temps == "mois") {
      p_ventes <- ggplot(ventes_groupees, aes(x = Periode, y = Total_Vendus, group = Produit, color = Produit,
                                              text = paste("Produit:", Produit, "<br>Période:", Periode, "<br>Unités:", Total_Vendus))) +
        geom_line(size = 1) +
        geom_point(size = 2)
    } else {
      p_ventes <- ggplot(ventes_groupees, aes(x = Periode, y = Total_Vendus, fill = Produit,
                                              text = paste("Produit:", Produit, "<br>Temps:", Periode, "<br>Unités:", Total_Vendus))) +
        geom_col() 
    }
    
    p_ventes <- p_ventes +
      theme_minimal(base_size = 14) +
      labs(x = titre_axe, y = "Total des unités vendues")
    
    if (input$choix_produit == "Tous les produits") {
      ggplotly(p_ventes, tooltip = "text")
    } else {
      p_ventes <- p_ventes + scale_fill_manual(values = c("#2C3E50")) + theme(legend.position = "none")
      ggplotly(p_ventes, tooltip = "text")
    }
  })
}

shinyApp(ui, server, options = list(
  host = "0.0.0.0",
  port = 5137
))
