
CREATE TABLE IF NOT EXISTS `blackmarket_data` (
  `item` varchar(50) NOT NULL,
  `sales` int(11) DEFAULT 0,
  `price` int(11) DEFAULT 0,
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

