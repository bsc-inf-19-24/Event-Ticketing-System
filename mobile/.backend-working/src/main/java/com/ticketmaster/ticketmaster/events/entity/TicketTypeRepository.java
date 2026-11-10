package com.ticketmaster.ticketmaster.events.entity;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface TicketTypeRepository extends JpaRepository<TicketType, Long> {

    List<TicketType> findByEventIdOrderByPriceAsc(Long eventId);

    List<TicketType> findByEventIdInOrderByPriceAsc(Collection<Long> eventIds);

    List<TicketType> findByEventId(Long eventId);

    /** PESSIMISTIC_WRITE — prevents overselling. Must run inside @Transactional. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT t FROM TicketType t WHERE t.id = :id")
    Optional<TicketType> findByIdForUpdate(@Param("id") Long id);
}