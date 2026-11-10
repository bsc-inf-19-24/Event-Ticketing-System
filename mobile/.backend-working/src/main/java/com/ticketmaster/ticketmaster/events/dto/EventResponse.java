package com.ticketmaster.ticketmaster.events.dto;

import com.ticketmaster.ticketmaster.events.entity.EventStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public record EventResponse(
        Long id,
        String title,
        String category,
        String genre,
        String venue,
        String location,
        LocalDateTime startTime,
        LocalDateTime endTime,
        EventStatus status,
        String availability,
        String coverImagePath,
        BigDecimal minPrice,
        long capacity,
        long remainingTickets,
        List<TicketTypeResponse> ticketTypes
) {
    public record TicketTypeResponse(
            Long id,
            String name,
            BigDecimal price,
            Integer totalQuantity,
            Integer remaining
    ) {
    }
}
