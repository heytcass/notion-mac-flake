use napi::bindgen_prelude::*;
use napi_derive::napi;

#[napi]
pub struct Database {
  _path: String,
}

#[napi]
pub struct Statement {
  _sql: String,
}

#[napi]
impl Database {
  #[napi(constructor)]
  pub fn new(path: String, _options: Option<String>) -> Result<Self> {
    println!("[SQLite Stub] Opening database: {}", path);
    Ok(Database { _path: path })
  }

  #[napi]
  pub fn prepare(&self, sql: String) -> Result<Statement> {
    println!("[SQLite Stub] Preparing statement: {}", sql);
    Ok(Statement { _sql: sql })
  }

  #[napi]
  pub fn exec(&self, sql: String) -> Result<()> {
    println!("[SQLite Stub] Executing: {}", sql);
    Ok(())
  }

  #[napi]
  pub fn close(&self) -> Result<()> {
    println!("[SQLite Stub] Closing database");
    Ok(())
  }

  #[napi]
  pub fn pragma(&self, pragma: String) -> Result<Option<String>> {
    println!("[SQLite Stub] Pragma: {}", pragma);
    Ok(None)
  }
}

#[napi]
impl Statement {
  #[napi]
  pub fn run(&self, _params: Option<String>) -> Result<String> {
    println!("[SQLite Stub] Running statement: {}", self._sql);
    Ok("{}".to_string())
  }

  #[napi]
  pub fn get(&self, _params: Option<String>) -> Result<Option<String>> {
    println!("[SQLite Stub] Getting from statement: {}", self._sql);
    Ok(None)
  }

  #[napi]
  pub fn all(&self, _params: Option<String>) -> Result<Vec<String>> {
    println!("[SQLite Stub] Getting all from statement: {}", self._sql);
    Ok(vec![])
  }
}

// Additional functions that better-sqlite3 expects
#[napi(js_name = "setErrorConstructor")]
pub fn set_error_constructor(_constructor: napi::JsFunction) -> Result<()> {
  println!("[SQLite Stub] setErrorConstructor called");
  Ok(())
}

// Main constructor function that better-sqlite3 expects
#[napi]
pub fn better_sqlite3(path: String, options: Option<String>) -> Result<Database> {
  Database::new(path, options)
}