mod auth;
mod config;
mod api;
mod executor;

use actix_web::{middleware, web, App, HttpServer};
use std::sync::Arc;
use log::{info, error};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logger
    env_logger::init();

    // Load configuration - try multiple locations
    let config_paths = vec![
        "/data/local/tmp/config.toml",     // Android deployment
        "deploy/config.toml",               // Development
        "config.toml",                      // Current directory
    ];

    let config = config_paths.iter()
        .find_map(|path| config::Config::load(path).ok())
        .unwrap_or_else(|| {
            error!("Failed to load config from any location: {:?}", config_paths);
            std::process::exit(1);
        });

    info!("OhMyPhone daemon starting...");
    info!("Binding to {}:{}", config.server.bind_address, config.server.port);

    // Initialize authentication service
    let auth_service = Arc::new(auth::AuthService::new(
        config.security.secret.clone(),
        config.security.timestamp_window,
    ));

    let bind_addr = format!("{}:{}", config.server.bind_address, config.server.port);

    // Start HTTP server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(auth_service.clone()))
            .wrap(middleware::Logger::default())
            .route("/status", web::get().to(api::status::get_status))
            .route("/radio/data", web::post().to(api::radio::toggle_data))
    })
    .bind(&bind_addr)?
    .run()
    .await
}
