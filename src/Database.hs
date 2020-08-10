{-# LANGUAGE TemplateHaskell #-}

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
import Control.Distributed.Process.Closure
import Control.Monad
import Data.Char
import Data.Map (Map)
import qualified Data.Map as Map
import Text.Printf
import Worker

type Database = ProcessId

createDB :: [NodeId] -> Process Database
createDB peers = spawnLocal (server peers)

set :: Database -> Key -> Value -> Process ()
set pid k v = send pid (Set k v)

get :: Database -> Key -> Process (Maybe Value)
get pid k = do
  (sendPort, recvPort) <- newChan
  send pid (Get k sendPort)
  receiveChan recvPort

rcdata :: RemoteTable -> RemoteTable
rcdata = Worker.__remoteTable

server :: [NodeId] -> Process ()
server peers = do
  self <- getSelfPid
  say $ printf "spawning on %s" (show self)

  ps <- forM peers $ \nid -> do
    say $ printf "spawning on %s" (show nid)
    spawn nid $(mkStaticClosure 'worker)

  forever $ do
    m <- expect
    case m of
      s@(Set k _) ->
        let pid = selectWorker ps k
         in send pid s
      g@(Get k _) ->
        let pid = selectWorker ps k
         in send pid g

-- キー空間の分割: ワーカーの数を法としてキーの最初の文字をとる
selectWorker :: [ProcessId] -> Key -> ProcessId
selectWorker ps [] = error "empty key"
selectWorker ps (k : ey) = ps !! (ord k `mod` (length ps))
