{-# LANGUAGE BangPatterns #-}

module Database
  ( Database,
    createDB,
    get,
    set,
    rcdata,
  )
where

import Control.Concurrent.STM
import Control.Distributed.Process
import Data.Map (Map)
import qualified Data.Map as Map

type Database = TVar (Map Key Value)

type Key = String

type Value = String

createDB :: [NodeId] -> Process Database
createDB _nodes = liftIO $ newTVarIO Map.empty

set :: Database -> Key -> Value -> Process ()
set db k v =
  liftIO $
    atomically $
      modifyTVar' db (\(!db') -> Map.insert k v db')

get :: Database -> Key -> Process (Maybe Value)
get db k =
  liftIO $
    atomically $ do
      m <- readTVar db
      return $ Map.lookup k m

rcdata :: RemoteTable -> RemoteTable
rcdata = id