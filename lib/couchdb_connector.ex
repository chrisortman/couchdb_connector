defmodule Couchdb.Connector do
  @moduledoc """
  Your primary interface for writing to and reading from CouchDB.
  The exchange format here are Maps. If you want to go more low
  level and deal with JSON strings instead, please consider using
  Couchdb.Connector.Reader or Couchdb.Connector.Writer.
  """

  import Couchdb.Connector.AsMap
  import Couchdb.Connector.AsJson
  alias Couchdb.Connector.Types
  alias Couchdb.Connector.Reader
  alias Couchdb.Connector.Writer

  @doc """
  Retrieve the document given by database properties and id, returning it
  as a Map, using no authentication.
  """
  @spec get(Types.db_properties, String.t) :: {:ok, map} | {:error, map}
  def get(db_props, id) do
    db_props
    |> Reader.get(id)
    |> as_map
  end

  @doc """
  Retrieve the document given by database properties and id, returning it
  as a Map, using the given basic auth credentials for authentication.
  """
  @spec get(Types.db_properties, Types.basic_auth, String.t) :: {:ok, map} | {:error, map}
  def get(db_props, basic_auth, id) do
    db_props
    |> Reader.get(basic_auth, id)
    |> as_map
  end

  @doc """
  Fetch a single uuid from CouchDB for use in a a subsequent create operation.
  Clients can retrieve the returned List of UUIDs by getting the value for key
  "uuids". The List contains only one element (UUID).
  """
  @spec fetch_uuid(Types.db_properties) :: {:ok, map} | {:error, String.t}
  def fetch_uuid(db_props) do
    db_props
    |> Reader.fetch_uuid()
    |> as_map
  end

  @doc """
  Create a new document from given map with given id, using no authentication.
  Clients must make sure that the id has not been used for an existing document
  in CouchDB.
  Either provide a UUID or consider using create_generate in case uniqueness cannot
  be guaranteed.
  """
  @spec create(Types.db_properties, map, String.t) :: {:ok, map} | {:error, map}
  def create(db_props, doc_map, id) do
    response = Writer.create(db_props, as_json(doc_map), id)
    response |> handle_write_response
  end

  defp handle_write_response({status, json}) do
    {status, %{:payload => as_map(json), :headers => %{}}}
  end

  defp handle_write_response({status, json, headers}) do
    {status, %{:payload => as_map(json), :headers => as_map(headers)}}
  end

  @doc """
  Create a new document from given map with a CouchDB generated id, using no
  authentication.
  Fetching the uuid from CouchDB does of course incur a performance penalty as
  compared to providing one.
  """
  @spec create_generate(Types.db_properties, map) :: {:ok, map} | {:error, map}
  def create_generate(db_props, doc_map) do
    {:ok, uuid_json} = Reader.fetch_uuid(db_props)
    uuid = hd(Poison.decode!(uuid_json)["uuids"])
    create(db_props, doc_map, uuid)
  end

  @doc """
  Update the given document, provided it contains an id field. Raise an error
  if it does not. Does not use any authentication.
  """
  @spec update(Types.db_properties, map) :: {:ok, map} | {:error, map}
  def update(db_props, doc_map) do
    case Map.fetch(doc_map, "_id") do
      {:ok, id} ->
        Writer.update(db_props, as_json(doc_map), id) |> handle_write_response
      :error ->
        raise RuntimeError, message:
          "the document to be updated must contain an \"_id\" field"
    end
  end

  @doc """
  Create a new document from given map with given id, using the provided basic
  authentication parameters.
  Clients must make sure that the id has not been used for an existing document
  in CouchDB.
  Either provide a UUID or consider using create_generate in case uniqueness cannot
  be guaranteed.
  """
  @spec create(Types.db_properties, Types.basic_auth, map, String.t) :: {:ok, map} | {:error,  map}
  def create(db_props, auth, doc_map, id) do
    response = Writer.create(db_props, auth, as_json(doc_map), id)
    response |> handle_write_response
  end

  @doc """
  Create a new document from given map with a CouchDB generated id, using the
  provided basic authentication parameters.
  Fetching the uuid from CouchDB does of course incur a performance penalty as
  compared to providing one.
  """
  @spec create_generate(Types.db_properties, Types.basic_auth, map) :: {:ok, map} | {:error, map}
  def create_generate(db_props, auth, doc_map) do
    {:ok, uuid_json} = Reader.fetch_uuid(db_props)
    uuid = hd(Poison.decode!(uuid_json)["uuids"])
    create(db_props, auth, doc_map, uuid)
  end

  @doc """
  Update the given document, provided it contains an id field. Raise an error
  if it does not. Makes use of the provided basic authentication parameters.
  """
  @spec update(Types.db_properties, Types.basic_auth, map)
    :: {:ok, map} | {:error, map}
  def update(db_props, auth, doc_map) do
    case Map.fetch(doc_map, "_id") do
      {:ok, id} ->
        response = Writer.update(db_props, auth, as_json(doc_map), id)
        response |> handle_write_response
      :error ->
        raise RuntimeError, message:
          "the document to be updated must contain an \"_id\" field"
    end
  end

  def destroy(db_props, id, rev) do
    Writer.destroy(db_props, id, rev) |> handle_write_response
  end

  def destroy(db_props, auth, id, rev) do
    Writer.destroy(db_props, auth, id, rev) |> handle_write_response
  end
end
