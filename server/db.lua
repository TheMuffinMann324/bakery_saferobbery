-- Database tables are created on start.
DB = {}

function DB.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `saferobbery_data` (
            `k` VARCHAR(32) NOT NULL,
            `v` LONGTEXT NOT NULL,
            PRIMARY KEY (`k`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `saferobbery_safes` (
            `id` VARCHAR(32) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `cooldown_until` INT NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

function DB.loadData(k)
    local v = MySQL.scalar.await('SELECT v FROM saferobbery_data WHERE k = ?', { k })
    if not v then return nil end
    local ok, decoded = pcall(json.decode, v)
    return ok and decoded or nil
end

function DB.saveData(k, value)
    MySQL.query.await('INSERT INTO saferobbery_data (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)', { k, json.encode(value) })
end

function DB.loadSafes()
    local rows = MySQL.query.await('SELECT id, data, cooldown_until FROM saferobbery_safes') or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ok, data = pcall(json.decode, r.data)
        if ok and type(data) == 'table' then
            data.id = r.id
            data._cooldownUntil = tonumber(r.cooldown_until) or 0
            out[#out + 1] = data
        end
    end
    return out
end

function DB.saveSafe(s, persisted)
    MySQL.query.await('INSERT INTO saferobbery_safes (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { s.id, json.encode(persisted) })
end

function DB.deleteSafe(id)
    MySQL.query.await('DELETE FROM saferobbery_safes WHERE id = ?', { id })
end

function DB.setCooldown(id, untilTs, definition)
    if definition then
        MySQL.query('UPDATE saferobbery_safes SET cooldown_until = ?, data = ? WHERE id = ?', { untilTs, json.encode(definition), id })
    else
        MySQL.query('UPDATE saferobbery_safes SET cooldown_until = ? WHERE id = ?', { untilTs, id })
    end
end
